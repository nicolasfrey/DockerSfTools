#!/usr/bin/env bash

commonDBRun() {
   local COMMAND=${1}

   if [[ "${APP__DB_TYPE}" = *[!\ ]* ]]; then
         local DB_TYPE
         DB_TYPE=$(echo "${APP__DB_TYPE}" | tr ",; " "\n")

         for DB in $DB_TYPE
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