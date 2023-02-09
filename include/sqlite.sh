#!/usr/bin/env bash

sqliteInitDB () {
   APP__DBAL_CONNECTION_SQLITE=${APP__DBAL_CONNECTION_SQLITE:-"default"}

   if [[ "${APP__DBAL_CONNECTION_SQLITE}" = *[!\ ]* ]]; then
      local DBAL_CONNECTION_SQLITE

      dockerRunBash "mkdir -p var/db && chmod 770 var/db" || displayError

      DBAL_CONNECTION_SQLITE=$(echo "${APP__DBAL_CONNECTION_SQLITE}" | tr ",; " "\n")

      for DB in $DBAL_CONNECTION_SQLITE
      do
         dockerRuncli bin/console doctrine:database:drop -f --connection=${DB}
         dockerRuncli bin/console doctrine:database:create --connection=${DB} || displayError
      done
   fi
}

sqliteDBReload () {
   displayMessage "${FUNCNAME[0]}, Not implemented yet"
}

sqliteLoadFixtures () {
   displayMessage "${FUNCNAME[0]}, Not implemented yet"
}

sqliteDBLoad () {
   displayMessage "${FUNCNAME[0]}, Not implemented yet"
}

sqliteBackup () {
   displayMessage "${FUNCNAME[0]}, Not implemented yet"
}

sqliteRestore () {
   displayMessage "${FUNCNAME[0]}, Not implemented yet"
}