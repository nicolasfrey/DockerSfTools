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
   dockerRuncli bin/console doctrine:fixtures:load -n --purge-with-truncate  || displayError
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

   local CURRENT_USER BACKUP_FILE STR_EXCLUDE_TABLE_DATA='' STR_EXCLUDE_SCHEMA=''
   CURRENT_USER=$(id -u -n)
   BACKUP_FILE="dump_$(date '+%Y%m%d%H%M').sql.backup"

   if [[ "${IGNORE}" != '--ignore-excludes' ]] && [[ "${APP__PSQL_EXCLUDE_TABLE_DATA}" = *[!\ ]* ]]; then
      EXCLUDE_DATA=$(echo "${APP__PSQL_EXCLUDE_TABLE_DATA}" | tr ",; " "\n")

      for DATA in $EXCLUDE_DATA
      do
          STR_EXCLUDE_TABLE_DATA+=" --exclude-table-data ${DATA}"
      done
   fi

   if [[ "${IGNORE}" != '--ignore-excludes' ]] && [[ "${APP__PSQL_EXCLUDE_SCHEMA}" = *[!\ ]* ]]; then
      STR_EXCLUDE_SCHEMA=" --exclude-schema \"${APP__PSQL_EXCLUDE_SCHEMA}\""
   fi

   echo "----> Backup ${SOURCE} database"
   ssh "${CURRENT_USER}@${DB_HOST}" PGPASSWORD="${DB_PASSWORD}" pg_dump "${STR_EXCLUDE_SCHEMA}" "${STR_EXCLUDE_TABLE_DATA}" --compress=9 --verbose --format=c --host=localhost --username="${DB_USER}" --dbname="${DB_DBNAME}" > ".docker/postgres/backup/${BACKUP_FILE}"
   echo " [OK] Backup ${SOURCE} database"
   echo ""

   echo "----> Clean localhost database"

   local SEQUENCES
   SEQUENCES=$(docker compose exec -T postgres psql --host=localhost --username="${APP__PSQL_USER}" --dbname="${APP__PSQL_DATABASE}" -t --command "SELECT string_agg(sequence_schema || '.\"' || sequence_name, '\",') FROM information_schema.sequences where sequence_catalog = '${APP__PSQL_DATABASE}'")
   if [[ "${SEQUENCES}" = *[!\ ]* ]]; then
      echo "Dropping sequences:${SEQUENCES}"
      docker compose exec postgres psql --host=localhost --username="${APP__PSQL_USER}" --dbname="${APP__PSQL_DATABASE}" --command "DROP SEQUENCE IF EXISTS ${SEQUENCES} CASCADE"
   fi

   local VIEWS
   VIEWS=$(docker compose exec -T postgres psql --host=localhost --username="${APP__PSQL_USER}" --dbname="${APP__PSQL_DATABASE}" -t --command "SELECT string_agg(table_schema || '.\"' || table_name || '\"', ',') FROM information_schema.tables where table_catalog = '${APP__PSQL_DATABASE}' AND table_schema not in('pg_catalog', 'information_schema') AND table_type='VIEW'")
   if [[ "${VIEWS}" = *[!\ ]* ]]; then
      echo "Dropping views:${VIEWS}"
      docker compose exec postgres psql --host=localhost --username="${APP__PSQL_USER}" --dbname="${APP__PSQL_DATABASE}" --command "DROP VIEW IF EXISTS ${VIEWS} CASCADE"
   fi

   local BASETBLS
   BASETBLS=$(docker compose exec -T postgres psql --host=localhost --username="${APP__PSQL_USER}" --dbname="${APP__PSQL_DATABASE}" -t --command "SELECT string_agg(table_schema || '.\"' || table_name || '\"', ',') FROM information_schema.tables where table_catalog = '${APP__PSQL_DATABASE}' AND table_schema not in('pg_catalog', 'information_schema') AND table_type='BASE TABLE'")
   if [[ "${BASETBLS}" = *[!\ ]* ]]; then
      echo "Dropping tables:${BASETBLS}"
      docker compose exec postgres psql --host=localhost --username="${APP__PSQL_USER}" --dbname="${APP__PSQL_DATABASE}" --command "DROP TABLE IF EXISTS ${BASETBLS} CASCADE"
   fi

   echo " [OK] Clean localhost database"
   echo ""

   echo "----> Restore database to localhost"
   docker compose exec postgres pg_restore --format=c --verbose --clean --no-privileges --no-owner --host=localhost --username="${APP__PSQL_USER}" --dbname="${APP__PSQL_DATABASE}" /var/backup/${BACKUP_FILE}
   echo " [OK] Restore database to localhost"
   echo ""

   echo "----> Remove backup file"
   rm -v ".docker/postgres/backup/${BACKUP_FILE}"
   echo " [OK] Remove backup file"

   echo ""
   echo -e "\e[34mDo you want to execute a migration in database '${DB_DBNAME}' ? (\e[33my/n\e[34m)\e[39m"
   # shellcheck disable=SC2162
   read -n 1
   echo ""
   if [[ $REPLY =~ ^[Yy]$ ]]; then
      docker compose run --rm -u "$USER":"$GROUP" phpcli bin/console doctrine:migrations:migrate -n
   fi
}

postgresBackup () {
   local gzfile

   # shellcheck disable=SC2046 disable=SC2006 disable=SC2116
   gzfile=$(echo `date '+%Y%m%d%H%M'`.backup.gz)

   docker compose exec postgres bash -c "PGPASSWORD=${APP__PSQL_PASSWORD} pg_dump --compress=9 --verbose --format=c --host=localhost --username=${APP__PSQL_USER} --dbname=${APP__PSQL_DATABASE} > /var/backup/${gzfile}"
}

postgresRestore () {
   local FILENAME=$1

   if [[ "${FILENAME}" == 'latest' ]]; then
      FILENAME=$(docker compose exec postgres bash -c "find ./var/backup -name *.backup.gz  -printf '%f\n' | sort -n | tail -n 1 | tr -dc '[[:print:]]'")
   fi

   if [[ -z ${FILENAME} ]]; then
      echo -e "\e[34m >>> Please specify a backup file to restore.\e[39m"
      docker compose exec postgres bash -c "find ./var/backup -name *.backup.gz  -printf '%f\n'"
      exit 0
   fi

   echo "Restore \"${FILENAME}\" backup"
   docker compose exec postgres pg_restore --format=c --verbose --clean --no-privileges --no-owner --host=localhost --username="${APP__PSQL_USER}" --dbname="${APP__PSQL_DATABASE}" /var/backup/${FILENAME}
}