#!/usr/bin/env bash

# Test login on artifactory
dockerIsConnected () {
   docker login "${APP__ARTIFACTORY_PATH}" < /dev/null >& /dev/null

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
      echo "----> Docker login ${APP__ARTIFACTORY_PATH}"
      docker login "${APP__ARTIFACTORY_PATH}" 2> /dev/null || displayError "Failed to connect to artifactory server. Please try again !"
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
   docker compose -f "${dc_common_lib_path}" --env-file .env up -d ${RECREATE} || displayError
}

dockerStop () {
   local ARGS=$*

   if [[ ${ARGS} == *"--destroy"* ]]; then
      local destroy_str="-v --rmi local --remove-orphans"
   fi

   if [[ ${ARGS} == *"--all"* ]]; then
      docker_compose_yml_list=$(docker compose ls | grep -v "/bin/common/" | sed "1 d" | awk '{print $3}')

      for docker_compose_yml in $docker_compose_yml_list
      do
         # shellcheck disable=SC2086
         docker compose -f "${docker_compose_yml}" down ${destroy_str}
      done
   else
      # shellcheck disable=SC2086
      docker compose down ${destroy_str}
   fi

   # Docker up common
   if [[ ${ARGS} == *"--full"* || ${ARGS} == *"--all"* ]]; then
      # shellcheck disable=SC2086
      docker compose -f "${dc_common_lib_path}" --env-file .env down ${destroy_str}
   fi
}

# restart docker
dockerRestart () {
    dockerStop "$@" && dockerStart "${1}"
}

# Test et récupère le dossier du projet COMMON
dockerGetCommonPath () {
   dc_common_lib_path="${APP__COMMON_LIB_PATH/#\~/$HOME}/docker-compose.yml"

   if [ ! -f "${dc_common_lib_path}" ]; then
      displayError "Common files not found. Check your project configuration (.env or .env.local)."
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