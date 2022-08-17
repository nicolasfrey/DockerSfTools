#!/usr/bin/env bash

source "$(dirname "$0")/include/update.sh"
source "$(dirname "$0")/include/common.sh"
source "$(dirname "$0")/include/docker.sh"
source "$(dirname "$0")/include/database.sh"
source "$(dirname "$0")/include/postgres.sh"
source "$(dirname "$0")/include/mongo.sh"
source "$(dirname "$0")/include/redis.sh"
source "$(dirname "$0")/include/system.sh"

# Start docker project
start () {
   dockerStart "$1"
}

# Stop docker project
stop () {
   dockerStop "$1"
}

# Restart docker project
restart () {
   dockerRestart
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
   commonDBRestore "$1"
}

# run Composer inside the app container
composer () {
   dockerRuncli composer "$*"
}

# run the Symfony console inside the app container
console () {
   dockerRuncli bin/console "$*"
}

# run bash on phpcli
bash () {
   dockerRuncli bash
}

# exec a php command into app container
php () {
    dockerRuncli php "$*"
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
      - HTTP: http://${APP__APP_NAME}.local.gd
      - MailDev: http://${APP__APP_NAME}.maildev.local.gd
      - Postgres via SSH: psql://${APP__PSQL_USER}:${APP__PSQL_PASSWORD}@${APP__APP_NAME}.postgres.local.gd:5432/${APP__PSQL_DATABASE}
      - SSH (for tunnel): ssh://proxy:pass@${APP__APP_NAME}.ssh.local.gd:2222"
}

# update project
update () {
   echo "----> Converting file to Unix format"
   ls -d -1 app/bin/* app/.env*
   dos2unix -q app/bin/* app/.env*
   echo " [OK] Converting file to Unix format"

   echo ""

   echo "----> Set executable"
   ls -d -1 bin/* app/bin/*
   chmod u+x bin/* app/bin/*
   echo " [OK] Set executable"

   echo ""

   echo "----> Add githooks"
   githooks
   echo " [OK] Githooks added"

   echo ""

   echo "----> Add default config"
   config
   echo " [OK] Default config added"

   echo ""

   echo "----> Install dependency"
   dockerRuncli composer install || displayError
   echo " [OK] Dependency installed"

   echo ""

   if isWeb; then
       echo "----> Create directories"
       systemCreateFolder "${APP__APPLICATION_FOLDER}"
       echo " [OK] Directories created"
       echo ""
   fi

   echo ""

   echo "----> Initialize database"
   commonInitDB
   echo " [OK] Database initialized"

   echo ""

   echo "----> Load fixture"
   commonLoadFixtures
   echo " [OK] Fixture loaded"
}

# remove containers, volumes and local images for this project
destroy () {
   if isWeb; then
       echo "----> Remove directory"
       dockerRunBash "rm -rf public/upload public/build vendor node_modules var bin/.phpunit"
       rm -f .docker/oracle/init/.cache
       echo " [OK] Directories removed"
       echo ""
   fi

   echo "----> Stop and remove docker images"
   dockerStop --destroy
   echo " [OK] Docker images removed"
}

# Install git hooks
githooks () {
  PRE_COMMIT_EXISTS=$([ -e .git/hooks/pre-commit ] && echo 1 || echo 0)
  COMMIT_MSG_EXISTS=$([ -e .git/hooks/commit-msg ] && echo 1 || echo 0)

  curl -s -o .git/hooks/pre-commit -X GET https://raw.githubusercontent.com/nicolasfrey/DockerSfTools/${BRANCHE}/config/pre-commit
  curl -s -o .git/hooks/commit-msg -X GET https://raw.githubusercontent.com/nicolasfrey/DockerSfTools/${BRANCHE}/config/commit-msg
  chmod +x .git/hooks/*;
  dos2unix -q .git/hooks/*

  if [ "$PRE_COMMIT_EXISTS" = 0 ]; then
      echo "Pre-commit git hook is installed!"
  else
      echo "Pre-commit git hook is updated!"
  fi

  if [ "$COMMIT_MSG_EXISTS" = 0 ]; then
      echo "Commit-msg git hook is installed!"
  else
      echo "Commit-msg git hook is updated!"
  fi
}

# Initialize config
config () {
  [ -f grumphp.yml ] || curl -s -o grumphp.yml -X GET https://raw.githubusercontent.com/nicolasfrey/DockerSfTools/${BRANCHE}/config/sample-grumphp.yml
  [ -f app/.php-cs-fixer.dist.php ] || curl -s -o app/.php-cs-fixer.dist.php -X GET https://raw.githubusercontent.com/nicolasfrey/DockerSfTools/${BRANCHE}/config/sample-cs-fixer.php
}

# run phpUnit
phpunit () {
   declare ARGS=$*

   if [ "$1" == 'init' ]; then
         dockerRuncli bin/console doctrine:database:create --env=test --if-not-exists || displayError
   elif [[ ${ARGS} == *"--coverage"* ]]; then
      dockerRuncli phpdbg -qrr ./bin/phpunit "${ARGS/--coverage/}"
   else
      dockerRuncli ./bin/phpunit --no-coverage "${ARGS}"
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
   declare ARGS="$*"

   dockerRuncli composer info |grep rector/rector >/dev/null 2>&1 || dockerRuncli composer require rector/rector --dev

   if dockerRuncli composer info|grep rector/rector >/dev/null 2>&1; then
      if [[ -z $1 ]]; then
         dockerRuncli vendor/bin/rector "--dry-run"
      else
         # shellcheck disable=SC2086
         #docker compose run --rm -u "$USER":"$GROUP" phpcli vendor/bin/rector ${ARGS}
         dockerRuncli vendor/bin/rector ${ARGS}
      fi
   else
      echo ""
      echo -e "\e[31mRector is not installed.\e[39m"
      echo ""
   fi
}

fileload () {
   systemFileload "$*"
}

# Return symfony logs
sflogs () {
    dockerRunBash "tail -f var/log/dev.log"
}

usage () {
    echo "usage: bin/app COMMAND [ARGUMENTS]

    selfupdate                                     Updates bin/app to the latest version.

    init                                           Initialize project
    update                                         Update current project (Reload db, launch composer install)
    destroy                                        Remove all the project Docker containers with their volumes

    start --force-recreate                         Start project
    stop --destroy                                 Stop project
    restart                                        Restart project

    composer                                       Use Composer inside the app container
    console                                        Use the Symfony console
    bash                                           Use bash inside the app container
    php                                            Executes a php command inside the app container

    phpunit <init...>                              Executes a phpUnit Tests. Add --coverage for coverage support. Init for create database
    grumphp <init|run...>                          Executes a GrumPHP task.
    rector <process...>                            Executes Rector Code Style Checker. Default dry-run mode.

    dbreload                                       Update schema and reload fixture
    dbload <PROD|STAGING> --ignore-excludes        Load choose environment DB into localhost
    fileload <PROD|STAGING>                        Load choose environment public files into local

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

   if [[ ! $1 =~ ^(version|init|update|start|stop|restart|bash|destroy|console|composer|php|phpunit|phpcsf|rector|backup|restore|dbload|fileload|dbreload|sflogs|grumphp|selfupdate)$ ]]; then
      echo "$1 is not a supported command"
      exit 1
   fi

   # Run dotenv
   dotenv

   # Common project
   dockerGetCommonPath

   # Get current user/group
   USER='docker'
   GROUP='docker'

   # Run command
   "$@"
}

main "$@"