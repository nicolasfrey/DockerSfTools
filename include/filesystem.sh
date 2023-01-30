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