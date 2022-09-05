#!/usr/bin/env bash

displayError () {
   TEXT=${1:-"An error occurred !!! Please, check your command history."}

   echo -e "\e[41m"
   echo -e "\n ${TEXT}"
   echo -e "\e[49m"
   exit
}

displayMessage () {
   TEXT=${1}

   echo -e "\e[44m\e[30m"
   echo -e "\n ${TEXT}"
   echo -e "\e[49m\e[39m"
}

# .env loading in the shell
dotenv () {
   # Ajout d'un prefix APP__ sur les variables, sinon, on a un conflit avec docker
   if [[ -f .env ]]; then
      # shellcheck disable=SC2046
      eval $(grep -v -e "^#" .env | sed "/^$/d" | xargs -I {} echo export \'APP__{}\')
   fi

   if [[ -f .env.local ]]; then
      # shellcheck disable=SC2046
      eval $(grep -v -e "^#" .env.local | sed "/^$/d" | xargs -I {} echo export \'APP__{}\')
   fi

   if isDosFile "${APP__SYMFONY_APP_PATH}/.env" || isDosFile "${APP__SYMFONY_APP_PATH}/.env.staging" || isDosFile "${APP__SYMFONY_APP_PATH}/.env.prod" || isDosFile ".env"; then
        echo -e "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n!!!!!!! Check line separator configuration !!!!!!!\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        exit 1
   fi

   # Lecture .env.prod si trouvé
   if [[ -f ${APP__SYMFONY_APP_PATH}/.env.prod ]]; then
      # shellcheck disable=SC2046
      eval $(grep -P -e "^(DATABASE_URL|UPLOAD_DIR|SERVER_IP|SRC_PATH)" "${APP__SYMFONY_APP_PATH}/.env.prod" | xargs -I {} echo export \'APP_PROD__{}\')
   fi

   # Lecture .env.staging si trouvé
   if [[ -f ${APP__SYMFONY_APP_PATH}/.env.staging ]]; then
      # shellcheck disable=SC2046
      eval $(grep -P -e "^(DATABASE_URL|UPLOAD_DIR|SERVER_IP|SRC_PATH)" "${APP__SYMFONY_APP_PATH}/.env.staging" | xargs -I {} echo export \'APP_STAGING__{}\')
   fi
}

isDosFile () {
   if [[ -f $1 ]]; then
      [[ $(dos2unix < $1 | cmp - $1 | wc -c) -gt 0 ]]
   fi
}

isWeb () {
   if [[ -z ${APP__IS_WEB} ]]; then
      return 1
   else
      return 0
   fi
}

testParam () {
   local PARAM=${1}
   local PARAM_NAME=${2}

   if [[ -n "${PARAM}" ]] && [[ ${PARAM} != "--${PARAM_NAME}" ]]; then
      echo -e "\e[41m"
      echo -e "\n Parameter \"${PARAM}\" is not defined ! \n\n Did you mean one of these? \n    --${PARAM_NAME}"
      echo -e "\e[49m"
      exit
   fi
}

versionToInt() {
    local IFS=.
    parts=($1)
    let val=1000000*parts[0]+1000*parts[1]+parts[2]
    echo $val
}