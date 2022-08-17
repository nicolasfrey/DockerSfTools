#!/usr/bin/env bash

commonDBRun() {
   local COMMAND=${1}

   if [[ "${APP__DB_LIST}" = *[!\ ]* ]]; then
         local DB_LIST
         DB_LIST=$(echo "${APP__DB_LIST}" | tr ",; " "\n")

         for DB in $DB_LIST
         do
            "${DB}""${COMMAND}" "${@:2}"
         done
      fi
}

commonDBBackup () {
   commonDBRun "Backup" "${@}"
}

commonDBRestore () {
   commonDBRun "Restore" "${@}"
}

commonDBReload () {
   commonDBRun "DBReload" "${@}"
}

commonDBLoad () {
   commonDBRun "DBLoad" "${@}"
}

commonInitDB () {
   commonDBRun "InitDB" "${@}"
}

commonLoadFixtures () {
   commonDBRun "LoadFixtures" "${@}"
}