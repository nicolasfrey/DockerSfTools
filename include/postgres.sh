#!/usr/bin/env bash

postgresDBReload () {
   systemCreateFolder "${APP__APPLICATION_FOLDER}"
   postgresInitDB
   postgresLoadFixtures
}

postgresInitDB () {
   dockerRuncli bin/console doctrine:schema:drop --full-database --force || displayError
   dockerRuncli bin/console doctrine:database:create --if-not-exists || displayError
   dockerRuncli bin/console doctrine:schema:update --force || displayError
}

postgresLoadFixtures () {
   if hasFixture; then
      dockerRuncli bin/console doctrine:fixtures:load -n --purge-with-truncate  || displayError
   fi
}

postgresDBLoad () {
   local SOURCE=$1
   local IGNORE=$2

   if [[ -z "${SOURCE}" ]]; then
      usage
      exit 0
   fi

   if [[ ! ${SOURCE} =~ ^PROD|STAGING$ ]]; then
      echo "${SOURCE} must be PROD or STAGING"
      exit 1
   fi

   if [[ -n "${IGNORE}" ]] && [[ ${IGNORE} != '--ignore-excludes' ]]; then
      displayError "Parameter \"${IGNORE}\" is not defined ! \n\n Did you mean one of these? \n    --ignore-excludes"
      exit
   fi

   local DATABASE="APP_${SOURCE}__DATABASE_URL"

   local pattern='^(pgsql|postgresql):\/\/(.*):(.*)@(.*):([0-9]*)\/([a-zA-Z0-9_\-]*)[\s]*\??(.*)$'
   if [[ ${!DATABASE} =~ $pattern ]]; then
      local DB_PROTOCOL=${BASH_REMATCH[1]}
      local DB_USER=${BASH_REMATCH[2]}
      local DB_PASSWORD=${BASH_REMATCH[3]}
      local DB_HOST=${BASH_REMATCH[4]}
      #local DB_PORT=${BASH_REMATCH[5]}
      local DB_DBNAME=${BASH_REMATCH[6]}
   fi

   if [[ -z "${DB_PROTOCOL}" ]] || [[ -z "${DB_HOST}" ]] || [[ -z "${DB_DBNAME}" ]] ; then
      echo "You must have host and DB name !"
      exit 1
   fi

   local CURRENT_USER BACKUP_DIR BACKUP_FILE BACKUP_PATH REMOTE_CMD
   local STR_EXCLUDE_TABLE_DATA='' STR_EXCLUDE_SCHEMA=''
   CURRENT_USER=$(id -u -n)
   BACKUP_DIR=".docker/postgres/backup"
   BACKUP_FILE="dump_$(date '+%Y%m%d%H%M').sql.backup"
   BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

   # Le dump est écrit par le shell courant, pas par le conteneur. Si le répertoire
   # appartient à root — cas classique quand c'est le conteneur postgres qui l'a créé — bash
   # échoue sur la redirection avant même de lancer ssh, et le message est illisible.
   mkdir -p "${BACKUP_DIR}" 2>/dev/null
   if [[ ! -w "${BACKUP_DIR}" ]]; then
      displayError "\"${BACKUP_DIR}\" n'est pas accessible en écriture pour ${CURRENT_USER}.\n Il appartient probablement à root : sudo chown -R ${CURRENT_USER} \"${BACKUP_DIR}\""
   fi

   if [[ "${IGNORE}" != '--ignore-excludes' ]] && [[ "${APP__PSQL_EXCLUDE_TABLE_DATA}" = *[!\ ]* ]]; then
      EXCLUDE_DATA=$(echo "${APP__PSQL_EXCLUDE_TABLE_DATA}" | tr ",; " "\n")

      for DATA in $EXCLUDE_DATA
      do
          STR_EXCLUDE_TABLE_DATA+=" --exclude-table-data '${DATA}'"
      done
   fi

   if [[ "${IGNORE}" != '--ignore-excludes' ]] && [[ "${APP__PSQL_EXCLUDE_SCHEMA}" = *[!\ ]* ]]; then
      STR_EXCLUDE_SCHEMA=" --exclude-schema '${APP__PSQL_EXCLUDE_SCHEMA}'"
   fi

   echo "----> Backup ${SOURCE} database"

   # Le mot de passe est lu sur l'entrée standard, et non passé sur la ligne de commande :
   # sur un serveur mutualisé, un simple `ps` la donne à voir à tout utilisateur local.
   REMOTE_CMD="read -r PGPASSWORD; export PGPASSWORD;"
   REMOTE_CMD+=" pg_dump${STR_EXCLUDE_SCHEMA}${STR_EXCLUDE_TABLE_DATA} --compress=9 --verbose"
   REMOTE_CMD+=" --format=c --host=localhost --username='${DB_USER}' --dbname='${DB_DBNAME}'"

   # Rien ne doit toucher la base locale avant d'être certain d'avoir un dump exploitable :
   # sinon un dump en échec détruit la base de développement sans rien pour la remplacer.
   if ! printf '%s\n' "${DB_PASSWORD}" | ssh "${CURRENT_USER}@${DB_HOST}" "${REMOTE_CMD}" > "${BACKUP_PATH}"; then
      rm -f "${BACKUP_PATH}"
      displayError "Le dump de ${SOURCE} a échoué. La base locale n'a pas été touchée."
   fi

   if [[ ! -s "${BACKUP_PATH}" ]]; then
      rm -f "${BACKUP_PATH}"
      displayError "Le dump de ${SOURCE} est vide. La base locale n'a pas été touchée."
   fi

   echo " [OK] Backup ${SOURCE} database ($(du -h "${BACKUP_PATH}" | cut -f1))"
   echo ""

   postgresCleanDB

   echo "----> Restore database to localhost"
   if ! docker compose exec -T postgres pg_restore --format=c --verbose --clean --if-exists --no-privileges --no-owner --host=localhost --username="${APP__PSQL_USER}" --dbname="${APP__PSQL_DATABASE}" "/var/backup/${BACKUP_FILE}"; then
      displayError "Le restore a échoué. Le dump est conservé : ${BACKUP_PATH}\n Il contient les données de ${SOURCE} : à supprimer dès que vous n'en avez plus besoin."
   fi
   echo " [OK] Restore database to localhost"
   echo ""

   echo "----> Remove backup file"
   rm -f "${BACKUP_PATH}"
   echo " [OK] Remove backup file"

   echo ""
   echo -e "\e[34mDo you want to execute a migration in local database '${APP__PSQL_DATABASE}' ? (\e[33my/n\e[34m)\e[39m"
   read -r -n 1
   echo ""
   if [[ $REPLY =~ ^[Yy]$ ]]; then
      dockerRuncli bin/console doctrine:migrations:migrate -n
   fi
}

postgresBackup () {
   local gzfile
   gzfile="$(date '+%Y%m%d%H%M').backup.gz"

   # Mot de passe passé par l'environnement plutôt qu'interpolé dans la commande, qui serait
   # visible dans la liste des processus du conteneur.
   docker compose exec -T -e PGPASSWORD="${APP__PSQL_PASSWORD}" postgres bash -c "pg_dump --compress=9 --verbose --format=c --host=localhost --username=${APP__PSQL_USER} --dbname=${APP__PSQL_DATABASE} > /var/backup/${gzfile}" || displayError "Le backup de la base locale a échoué."
}

postgresRestore () {
   local FILENAME=$1

   # Chemin absolu : le montage est /var/backup. La forme relative ne fonctionnait que parce
   # que le répertoire de travail du conteneur postgres se trouve être la racine.
   if [[ "${FILENAME}" == 'latest' ]]; then
      FILENAME=$(docker compose exec -T postgres bash -c "find /var/backup -name '*.backup.gz' -printf '%f\n' | sort -n | tail -n 1 | tr -dc '[[:print:]]'")
   fi

   if [[ -z ${FILENAME} ]]; then
      echo -e "\e[34m >>> Please specify a backup file to restore.\e[39m"
      docker compose exec -T postgres bash -c "find /var/backup -name '*.backup.gz' -printf '%f\n'"
      exit 0
   fi

   postgresCleanDB

   echo "Restore \"${FILENAME}\" backup"
   docker compose exec -T postgres pg_restore --format=c --verbose --no-privileges --no-owner --host=localhost --username="${APP__PSQL_USER}" --dbname="${APP__PSQL_DATABASE}" "/var/backup/${FILENAME}"
}

postgresCleanDB () {
   echo "----> Clean local database"
   docker compose exec -T postgres psql --host=localhost --username="${APP__PSQL_USER}" --dbname="${APP__PSQL_DATABASE}" < bin/db/postgres/clean.sql
   echo " [OK] Clean local database"
   echo ""
}