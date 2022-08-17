#!/usr/bin/env bash

# Test login on artifactory
dockerIsConnected () {
   docker login artifactory.groupe.pharmagest.com < /dev/null >& /dev/null

   # shellcheck disable=SC2181
   if [ $? -eq 0 ]; then
     return 0
   else
     return 1
   fi
}

# Login on artifactory
dockerLogin () {
   if ! dockerIsConnected; then
      echo "----> Docker login artifactory.groupe.pharmagest.com"
      docker login artifactory.groupe.pharmagest.com 2> /dev/null || displayError "Failed to connect to artifactory server. Please try again !"
   fi
}

# start docker
dockerStart () {
   local RECREATE=${1}
   testParam "${RECREATE}" "force-recreate"

   # create network
   dockerCreateNetwork "nginx-proxy"

   # Docker recreate
   # shellcheck disable=SC2086
   docker compose up -d ${RECREATE} || displayError

   # Docker up common
   # shellcheck disable=SC2086
   docker compose -f "${dc_common_lib_path}" up -d ${RECREATE} || displayError
}

# stop docker
dockerStop () {
   local DESTROY=${1}
   testParam "${DESTROY}" "destroy"

   if [[ "${DESTROY}" == '--destroy' ]]; then
      local destroy_str="-v --rmi local --remove-orphans"
   fi

   # shellcheck disable=SC2086
   docker compose down ${destroy_str}

   # Docker up common
   docker compose -f "${dc_common_lib_path}" down
}

# restart docker
dockerRestart () {
    dockerStop "${1}" && dockerStart "${1}"
}

# Test et récupère le dossier du projet COMMON
dockerGetCommonPath () {
   dc_common_lib_path="${APP__COMMON_LIB_PATH/#\~/$HOME}/docker-compose.yml"

   if [ ! -f "${dc_common_lib_path}" ]; then
      displayError "Common files not found. Clone git project and check your project configuration (.env or .env.local)."
      exit 1
   fi
}

dockerCreateNetwork () {
   local NETWORK_NAME=${1:-"nginx-proxy"}

   # create network
   docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1 || docker network create "${NETWORK_NAME}" >/dev/null || displayError
}

dockerRuncli () {
   docker compose run --rm -u "$USER":"$GROUP" phpcli "${@}"
}

dockerRunBash () {
   local BASH=${1}

   docker compose run --rm -u "$USER":"$GROUP" phpcli bash -c "${BASH}"
}