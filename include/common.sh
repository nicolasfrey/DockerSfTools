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

displayWarning () {
   TEXT=${1}
   echo -e "\e[31m${TEXT}\e[39m"
}

# .env loading in the shell
dotenv () {

   if [[ ! -f .env ]]; then
      displayError "Config file not found. Check, if you have .env file !"
   fi

   checkLineSeparators ".env"

   # Ajout d'un prefix APP__ sur les variables, sinon, on a un conflit avec docker
   if [[ -f .env ]]; then
      # shellcheck disable=SC2046
      eval $(grep -v -e "^#" .env | sed "/^$/d" | xargs -I {} echo export \'APP__{}\')
   fi

   if [[ -f .env.local ]]; then
      # shellcheck disable=SC2046
      eval $(grep -v -e "^#" .env.local | sed "/^$/d" | xargs -I {} echo export \'APP__{}\')
   fi

   # Lecture .env.prod si trouvé
   if [[ -f ${APP__SYMFONY_APP_PATH}/.env.prod ]]; then
      checkLineSeparators "${APP__SYMFONY_APP_PATH}/.env.prod"
      # shellcheck disable=SC2046
      eval $(grep -P -e "^(DATABASE_URL|UPLOAD_DIR|SERVER_IP|SRC_PATH)" "${APP__SYMFONY_APP_PATH}/.env.prod" | xargs -I {} echo export \'APP_PROD__{}\')
   else
      displayWarning "Warning, \"${APP__SYMFONY_APP_PATH}/.env.prod\" not found !"
   fi

   # Lecture .env.staging si trouvé
   if [[ -f ${APP__SYMFONY_APP_PATH}/.env.staging ]]; then
      checkLineSeparators "${APP__SYMFONY_APP_PATH}/.env.staging"
      # shellcheck disable=SC2046
      eval $(grep -P -e "^(DATABASE_URL|UPLOAD_DIR|SERVER_IP|SRC_PATH)" "${APP__SYMFONY_APP_PATH}/.env.staging" | xargs -I {} echo export \'APP_STAGING__{}\')
   else
         displayWarning "Warning, \"${APP__SYMFONY_APP_PATH}/.env.staging\" not found !"
   fi
}

checkLineSeparators() {
   if isDosFile "$1" ; then
      echo -e "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo -e "! Check line separator configuration for $1"
      echo -e "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      exit 1
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

hasJWT () {
   if grep -q "lexik/jwt-authentication-bundle" "app/composer.json"; then
      return 0
   else
      return 1
   fi
}

hasFixture () {
   if grep -q "doctrine/doctrine-fixtures-bundle" "app/composer.json"; then
      return 0
   else
      return 1
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