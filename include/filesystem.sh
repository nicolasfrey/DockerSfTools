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

systemFileInit() {
   local ARGS=$*

   declare CONTENT
   declare SRC
   declare SRC_FORMATTED
   declare DEST

   CONTENT=$(echo "${APP__INIT_FILESYSTEM}" | tr , ' ')
   declare -A ARR="(${CONTENT})"

   if [[ ${#ARR[@]} == 0 ]]; then
     echo "No files to process"
   fi

   for key in "${!ARR[@]}"; do
      SRC="${APP__ROOT_PATH}/${key}"
      DEST="${APP__ROOT_PATH}/${ARR[${key}]}"

      if [[ ${ARGS} == *"--reset"* ]]; then
         if [[ -d "${DEST}" || -f "${DEST}" ]]; then
            rm -Rf "${DEST}"
         fi
      fi;

      SRC_FORMATTED=$(echo "${SRC}" | tr -d "*")

      if [[ ! -d "${SRC_FORMATTED}" && ! -f "${SRC_FORMATTED}" ]]; then
         echo "Path ${SRC} not found"
         exit 1
      fi

      if [[ -d "${SRC_FORMATTED}" ]]; then
         mkdir -p "${DEST}"
         echo "Copy ${SRC} in ${DEST}"
         # shellcheck disable=SC2086
         cp -r ${SRC} ${DEST}
      else
         echo "Copy ${SRC} in ${DEST}"
         # shellcheck disable=SC2086
         cp ${SRC} ${DEST}
      fi
   done
}