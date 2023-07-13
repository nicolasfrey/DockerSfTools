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

   SERVER_IP="APP_${SOURCE}__SERVER_IP"
   SRC_PATH="APP_${SOURCE}__SRC_PATH"

   if [[ -z "${SOURCE}" ]]; then
      usage
      exit 0
   fi

   if [[ ! ${SOURCE} =~ ^PROD|STAGING$ ]]; then
      echo "${SOURCE} must be PROD or STAGING"
      exit 1
   fi

   if [[ "${APP__APPLICATION_FOLDER}" = *[!\ ]* ]]; then
         local FOLDERS
         FOLDERS=$(echo "${APP__APPLICATION_FOLDER}" | tr ",; " "\n")

         for FOLDER in $FOLDERS
         do
            echo "----> Rsync ${FOLDER} directory"
            rsync -av "deploy@${!SERVER_IP}:${!SRC_PATH}/current/${APP__SYMFONY_APP_PATH}/${FOLDER}/*" "./${APP__SYMFONY_APP_PATH}/${FOLDER}"
            echo " [OK] Rsync ${FOLDER} directory"
            echo ""

            echo "----> Change permissions"
            dockerRunBash "chown ${USER}:${GROUP} ${FOLDER} -R && chmod 770 ${FOLDER} -R" || displayError
            echo " [OK] Change permissions"
            echo ""
         done
   fi
}
