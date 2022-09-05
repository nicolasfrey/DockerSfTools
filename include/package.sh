#!/usr/bin/env bash

BRANCHE='master'

# Version
packageVersion () {
   echo ""
   echo -e "\e[34mbin/app\e[39m version \e[33m$(packageGetVersion)\e[39m"
   echo ""

   if packageIsUpToDate; then
      echo -e "\e[31mUne nouvelle version est disponible (\e[33m$(packageGetGitVersion)\e[31m). Pensez à mettre à jour votre version avec la commande \"\e[39mbin/app selfupdate\e[31m\"\e[39m\n"
   fi
}

packageGetVersion () {
   cat ./bin/VERSION
}

packageGetGitVersion () {
   #curl -s https://raw.githubusercontent.com/nicolasfrey/DockerSfTools/master/VERSION
   curl -s https://raw.githubusercontent.com/nicolasfrey/DockerSfTools/feature/uptodate/VERSION
}

packageIsUpToDate () {
   GIT_VERSION=$(versionToInt "$(packageGetGitVersion)")
   LOCAL_VERSION=$(versionToInt "$(packageGetVersion)")

   if [ "$LOCAL_VERSION" \< "$GIT_VERSION" ]; then
      return 0
   else
      return 1
   fi
}

packageSelfUpdate () {
   rm -rf ./bin
   git clone --branch ${BRANCHE} https://github.com/nicolasfrey/DockerSfTools.git bin
   packageCleanDirectory
   bin/app version
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