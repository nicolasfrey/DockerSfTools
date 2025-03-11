#!/usr/bin/env bash

source "$(dirname "$0")/include/package.sh"
source "$(dirname "$0")/include/common.sh"
source "$(dirname "$0")/include/docker.sh"
source "$(dirname "$0")/include/database.sh"
source "$(dirname "$0")/include/postgres.sh"
source "$(dirname "$0")/include/mongo.sh"
source "$(dirname "$0")/include/redis.sh"
source "$(dirname "$0")/include/sqlite.sh"
source "$(dirname "$0")/include/filesystem.sh"

# Start docker project
start () {
   dockerStart "$1"
}

# Stop docker project
stop () {
   dockerStop "$@"
}

# Kill docker project
kill () {
   dockerKill
}

# Restart docker project
restart () {
   dockerRestart "$@"
}

# Reset DB and load fixtures
dbreload () {
   commonDBReload
}

# Load BD from Staging or Production
dbload () {
   commonDBLoad "$1" "$2"
}

# Backup DB
backup () {
   commonDBBackup
}

# Restore DB
restore () {
   commonDBRestore "$@"
}

# run Composer inside the app container
composer () {
   dockerRuncli composer "$@"
}

# run the Symfony console inside the app container
console () {
   dockerRuncli bin/console "$@"
}

# run bash on phpcli
bash () {
   dockerRuncli bash
}

# exec a php command into app container
php () {
    dockerRuncli php "$@"
}

# init project
init () {
   # Login on artifactory
   dockerLogin

   # Start docker
   dockerStart

   # Update()
   echo ""
   update
   echo ""

   displayMessage "  Project initialized successfully.
      - HTTP: http://${APP__APP_NAME}.nip.io
      - MailDev: http://${APP__APP_NAME}.maildev.nip.io
      - Postgres via SSH: psql://${APP__PSQL_USER}:${APP__PSQL_PASSWORD}@${APP__APP_NAME}.postgres.nip.io:5432/${APP__PSQL_DATABASE}
      - MongoDB via SSH: mongodb://${APP__MDB_USER}:${APP__MDB_PASSWORD}@${APP__APP_NAME}.mongodb.nip.io:27017/${APP__MDB_DATABASE}
      - SSH (for tunnel): ssh://proxy:pass@ssh.nip.io:2222"
}

# update project
update () {
   echo "----> Converting file to Unix format"
   ls -d -1 app/bin/* app/.env*
   dos2unix -q app/bin/* app/.env*
   echo " [OK] Converting file to Unix format"

   echo ""

   echo "----> Set executable"
   ls -d -1 bin/app app/bin/*
   chmod u+x bin/app app/bin/*
   echo " [OK] Set executable"

   echo ""

   if isWeb; then
       echo "----> Create directories"
       systemCreateFolder "${APP__APPLICATION_FOLDER}"
       echo " [OK] Directories created"
       echo ""
   fi

   echo ""

   echo "----> Install dependency"
   dockerRuncli composer install || displayError
   echo " [OK] Dependency installed"

   commonInitDB
   commonLoadFixtures

   if hasJWT; then
      echo ""
      echo "----> Generate key-pair"
      dockerRuncli bin/console lexik:jwt:generate-keypair --skip-if-exists
      echo " [OK] Key-pair generated"
   fi
}

# remove containers, volumes and local images for this project
destroy () {
   if isWeb; then
       echo "----> Remove directory"

       if [[ "${APP__APPLICATION_FOLDER}" = *[!\ ]* ]]; then
             local FOLDERS
             FOLDERS=$(echo "${APP__APPLICATION_FOLDER}" | tr ",; " "\n")

             for FOLDER in $FOLDERS
             do
                dockerRunBash "rm -rf ./${FOLDER}"
             done
       fi

       dockerRunBash "rm -rf public/build vendor node_modules var bin/.phpunit"
       rm -f .docker/oracle/init/.cache
       echo " [OK] Directories removed"
       echo ""
   fi

   echo "----> Stop and remove docker images"
   dockerStop --destroy
   echo " [OK] Docker images removed"
}

config () {
   if [[ -z $1 ]]; then
      packageInit
   elif [ "$1" == '--destroy' ]; then
      packageDestroy
   else
      displayError "Parameter \"${1}\" is not defined ! \n\n Did you mean one of these? \n    --destroy"
      exit
   fi
}

version () {
   packageVersion
}

selfupdate () {
   packageSelfUpdate
}

# run phpUnit
phpunit () {
   declare ARGS=$*

   if [ "$1" == 'init' ]; then
         dockerRuncli bin/console doctrine:database:create --env=test --if-not-exists || displayError
   elif [[ ${ARGS} == *"--coverage"* ]]; then
      # shellcheck disable=SC2086
      dockerRuncli phpdbg -qrr ./bin/phpunit ${ARGS/--coverage/}
   else
      # shellcheck disable=SC2086
      dockerRuncli ./bin/phpunit --no-coverage ${ARGS}
   fi
}

# run php-cs-fixer
grumphp () {
   declare ARGS="$*"

   if [[ -z $1 ]]; then
      dockerRuncli grumphp --config=../grumphp.yml run
   elif [ "$1" == 'init' ]; then
       githooks
   else
      # shellcheck disable=SC2086
      dockerRuncli grumphp --config=../grumphp.yml ${ARGS}
   fi
}

rector () {
   dockerRuncli grumphp --config=../grumphp.yml run --tasks=rector
}

phpcsfixer () {
   dockerRuncli grumphp --config=../grumphp.yml run --tasks=phpcsfixer
}

phpstan () {
   dockerRuncli grumphp --config=../grumphp.yml run --tasks=phpstan
}

fileload () {
   systemFileload "$@"
}

# Return symfony logs
sflogs () {
    dockerRunBash "tail -f var/log/dev.log"
}

usage () {
    echo "usage: bin/app COMMAND [ARGUMENTS]

    selfupdate                                     Updates bin/app to the latest version.

    config --destroy                               Initialize bin/app, grumphp, phpCSFixer, githooks. Add --destroy for clean project
    init                                           Initialize project
    update                                         Update current project (Reload db, launch composer install)
    destroy                                        Remove all the project Docker containers with their volumes

    start --force-recreate                         Start project
    stop --destroy --full --all                    Stop project. Add --destroy for remove images and orphans.
                                                   Add --full for stop common containers. Add --all for stop ALL DOCKER COMPOSE project.
    kill                                           Kill all containers
    restart --full                                 Restart project. Add --full for restart common containers.

    composer                                       Use Composer inside the app container
    console                                        Use the Symfony console
    bash                                           Use bash inside the app container
    php                                            Executes a php command inside the app container

    phpunit <init...>                              Executes a phpUnit Tests. Add --coverage for coverage support. Init for create database
    grumphp <init|run...>                          Executes a GrumPHP task.
    rector                                         Executes Rector Code Style Checker.
    phpcsfixer                                     Executes phpCSFixer (PHP Coding Standards Fixer).
    phpstan                                        Executes PHPStan - PHP Static Analysis Tool.

    dbreload                                       Update schema and reload fixture
    dbload <PROD|STAGING> --ignore-excludes        Load choose environment DB into localhost
    fileload <PROD|STAGING>                        Load choose environment public files into local
    fileinit --reset                               Initialize files project. Add --reset for reset folder before.

    backup                                         Backup database in .docker/postgres/YmdHi.backup.gz
    restore <filename|latest>                      Restore database

    sflogs                                         Return sf logs.
    "
}

main () {
   if [[ -z $1 ]]; then
      usage
      exit 0
   fi

   if [[ ! $1 =~ ^(version|config|init|update|start|stop|restart|kill|bash|destroy|console|composer|php|phpunit|grumphp|phpstan|phpcsfixer|rector|backup|restore|dbload|fileload|dbreload|sflogs|selfupdate)$ ]]; then
      echo "$1 is not a supported command"
      exit 1
   fi

   # Run dotenv
   dotenv

   # Common project
   dockerGetCommonPath

   # Check if uptodate
   packageCheckIfUpToDate

   # Get current user/group
   USER='docker'
   GROUP='docker'

   # Run command
   "$@"
}

main "$@"
