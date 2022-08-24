#!/usr/bin/env bash

mongoDBReload () {
   systemCreateFolder "${APP__APPLICATION_FOLDER}"
   mongoInitDB
   mongoLoadFixtures
}

mongoInitDB () {
   APP__DB_MANAGER_LIST=${APP__DB_MANAGER_LIST:-"default"}

   if [[ "${APP__DB_MANAGER_LIST}" = *[!\ ]* ]]; then
      local DB_MANAGER_LIST
      DB_MANAGER_LIST=$(echo "${APP__DB_MANAGER_LIST}" | tr ",; " "\n")

      for DB in $DB_MANAGER_LIST
      do
         echo "dockerRuncli bin/console doctrine:mongodb:schema:drop --dm=${DB}"
         echo "dockerRuncli bin/console doctrine:mongodb:schema:create --dm=${DB} || displayError"
      done
   fi
}

mongoLoadFixtures () {
   dockerRuncli bin/console doctrine:mongodb:fixtures:load -n || displayError
}

mongoDBLoad () {
   displayMessage "${FUNCNAME[0]}, Not implemented yet"
}

mongoBackup () {
   displayMessage "${FUNCNAME[0]}, Not implemented yet"
}

mongoRestore () {
   displayMessage "${FUNCNAME[0]}, Not implemented yet"
}