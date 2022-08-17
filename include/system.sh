#!/usr/bin/env bash

systemCreateFolder () {
   if [[ "${APP__APPLICATION_FOLDER}" = *[!\ ]* ]]; then
      local FOLDERS
      FOLDERS=$(echo "${APP__APPLICATION_FOLDER}" | tr ",; " "\n")

      for FOLDER in $FOLDERS
      do
         dockerRunBash "mkdir -p ${FOLDER} && chmod 777 ${FOLDER} -R" || displayError
      done
   fi
}

systemRemoveFolder () {
   if [[ "${APP__APPLICATION_FOLDER}" = *[!\ ]* ]]; then
      local FOLDERS
      FOLDERS=$(echo "${APP__APPLICATION_FOLDER}" | tr ",; " "\n")

      for FOLDER in $FOLDERS
      do
         dockerRunBash "mkdir -p ${FOLDER} && chmod 777 ${FOLDER} -R" || displayError
      done
   fi
}

systemFileload () {
   declare SOURCE=$1

   if [[ -z "${SOURCE}" ]]; then
      usage
      exit 0
   fi

   if [[ ! ${SOURCE} =~ ^PROD|STAGING$ ]]; then
      echo "${SOURCE} must be PROD or STAGING"
      exit 1
   fi

   UPLOAD_DIR="APP_${SOURCE}__UPLOAD_DIR"
   SERVER_IP="APP_${SOURCE}__SERVER_IP"
   SRC_PATH="APP_${SOURCE}__SRC_PATH"

   echo "----> Rsync ${!UPLOAD_DIR} directory"
   rsync -av "deploy@${!SERVER_IP}:${!SRC_PATH}/current/${APP__SYMFONY_APP_PATH}/public/upload/*" "./${APP__SYMFONY_APP_PATH}/public/upload/"
   echo " [OK] Rsync ${!UPLOAD_DIR} directory"
   echo ""

   echo "----> Change permissions"
   dockerRunBash "chmod 777 public/upload -R"
   echo " [OK] Change permissions"
}