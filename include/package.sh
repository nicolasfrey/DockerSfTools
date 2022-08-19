#!/usr/bin/env bash

BRANCHE='master'

# Version
packageVersion () {
   VERSION='3.0.0'
   echo ""
   echo -e "\e[34mbin/app\e[39m version \e[33m${VERSION}\e[39m"
   echo ""
}

packageSelfupdate () {
   echo "TODO: update"

   # Récupération du zip sur github. Décompression du dossier bin dans le projet.

   # https://askubuntu.com/questions/653505/uncompress-file-from-url-to-hard-disk
   # https://unix.stackexchange.com/questions/59276/how-to-extract-only-a-specific-folder-from-a-zipped-archive-to-a-given-directory

   #curl --create-dirs -k -o bin/app -X GET https://raw.githubusercontent.com/nicolasfrey/DockerSfTools/${BRANCHE}/bin/app
   #chmod +x bin/app
   #bin/app version
}

packageDestroy() {
   echo "----> Remove githooks"
      rm .git/hooks/pre-commit .git/hooks/commit-msg
   echo " [OK] Githooks removed"
}

packageInit () {
   echo "----> Add githooks"
   packageAddGithooks
   echo " [OK] Githooks added"

   echo ""

   echo "----> Add default config"
   packageAddConfigFile
   echo " [OK] Default config added"

   echo ""

   echo "----> Clean Git and directory structure"
   packageCleanDirectory
   echo " [OK] Directories remove"
}

# Remove unnecessary folders
packageCleanDirectory () {
   rm -rf bin/.git
}

# Install git hooks
packageAddGithooks () {
   PRE_COMMIT_EXISTS=$([ -e .git/hooks/pre-commit ] && echo 1 || echo 0)
   COMMIT_MSG_EXISTS=$([ -e .git/hooks/commit-msg ] && echo 1 || echo 0)

   cp -f bin/config/pre-commit .git/hooks/pre-commit
   cp -f bin/config/commit-msg .git/hooks/commit-msg

   if [ "$PRE_COMMIT_EXISTS" = 0 ]; then
      echo "Pre-commit git hook is installed!"
   else
      echo "Pre-commit git hook is updated!"
   fi

   if [ "$COMMIT_MSG_EXISTS" = 0 ]; then
      echo "Commit-msg git hook is installed!"
   else
      echo "Commit-msg git hook is updated!"
   fi
}

# Initialize config
packageAddConfigFile () {
   [ -f grumphp.yml ] || cp -f bin/config/sample-grumphp.yml grumphp.yml
   [ -f app/.php-cs-fixer.dist.php ] || cp -f bin/config/sample-cs-fixer.php app/.php-cs-fixer.dist.php
}