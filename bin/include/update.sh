#!/usr/bin/env bash

BRANCHE='master'

# Version
version () {
   VERSION='2.4.2'
   echo ""
   echo -e "\e[34mbin/app\e[39m version \e[33m${VERSION}\e[39m"
   echo ""
}

selfupdate () {
   echo "TODO: update"

   # Récupération du zip sur github. Décompression du dossier bin dans le projet.

   # https://askubuntu.com/questions/653505/uncompress-file-from-url-to-hard-disk
   # https://unix.stackexchange.com/questions/59276/how-to-extract-only-a-specific-folder-from-a-zipped-archive-to-a-given-directory

   #curl --create-dirs -k -o bin/app -X GET https://raw.githubusercontent.com/nicolasfrey/DockerSfTools/${BRANCHE}/bin/app
   #chmod +x bin/app
   #bin/app version
}