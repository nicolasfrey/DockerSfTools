#!/usr/bin/env bash

BRANCHE='master'

# VERSION DE RELAIS — 4.18.0, terminale sur ce dépôt.
#
# DockerSfTools n'est plus développé ici. Cette version n'existe que pour conduire
# les projets encore branchés sur ce dépôt vers celui qui a pris la suite, sans que
# personne ait à éditer un fichier à la main.
#
# Concrètement : un `bin/app selfupdate` depuis une version antérieure atterrit ici,
# et le `selfupdate` SUIVANT récupère la version courante depuis le dépôt de
# destination. Deux commandes, rien à savoir.
DOCKERSFTOOLS_REPO_DEFAULT='ssh://git@bitbucket.groupe.pharmagest.com:7999/welsitl/dockersftools.git'

# Version
packageVersion () {
   echo ""
   echo -e "\e[34mbin/app\e[39m version \e[33m$(packageGetVersion)\e[39m"
   echo ""
   echo -e "\e[33mVersion de RELAIS.\e[39m DockerSfTools n'est plus distribué depuis GitHub."
   echo -e "Lance \e[34mbin/app selfupdate\e[39m pour récupérer la version courante depuis le dépôt qui a pris la suite."
   echo ""
}

packageGetVersion () {
   cat ./bin/VERSION
}

packageGetGitVersion () {
   curl -s "https://raw.githubusercontent.com/nicolasfrey/DockerSfTools/${BRANCHE}/VERSION"
}

# Muette : ce dépôt est gelé, il n'annoncera plus jamais de nouvelle version. Continuer
# à interroger GitHub ne ferait que comparer 4.18.0 à elle-même. C'est `packageVersion`
# qui porte désormais le message, à chaque affichage et non une fois par semaine.
packageIsUpToDate () {
   return 0
}

packageCheckIfUpToDate() {
   [ -f "$FILE" ]; touch ./bin/.last_check_version

   if [ "$(find ./bin -name '.last_check_version' -mtime +7)" ]; then
      packageIsUpToDate
   fi
}

# Conduit le projet vers le dépôt qui a pris la suite.
#
# On clone À CÔTÉ, puis on remplace. L'ordre inverse — `rm -rf ./bin` d'abord — laissait
# le projet SANS outil quand le clone échouait, donc incapable de réessayer. C'était
# tolérable tant que la source était un dépôt public toujours joignable ; la destination
# demande un réseau d'entreprise et une authentification, donc l'échec devient courant.
# C'est précisément ici qu'il ne faut pas perdre bin/.
packageSelfUpdate () {
   local url tmp
   url="${DOCKERSFTOOLS_REPO:-$DOCKERSFTOOLS_REPO_DEFAULT}"
   tmp="$(mktemp -d)" || return 1

   echo "Récupération depuis $url"

   if ! git clone --branch "${BRANCHE}" "$url" "$tmp/bin"; then
      rm -rf "$tmp"
      echo "" >&2
      echo "Échec de la récupération — bin/ est laissé intact, rien n'est perdu." >&2
      echo "Ce dépôt-ci ne distribue plus DockerSfTools : la suite vit sur un dépôt" >&2
      echo "privé, qui demande d'être sur le réseau de l'organisation et authentifié." >&2
      echo "Si tu n'en fais pas partie, cette version 4.18.0 est la dernière disponible" >&2
      echo "et reste pleinement fonctionnelle." >&2
      echo "" >&2
      echo "Pour viser un autre dépôt : DOCKERSFTOOLS_REPO=<url> bin/app selfupdate" >&2
      return 1
   fi

   rm -rf ./bin
   mv "$tmp/bin" ./bin
   rm -rf "$tmp"
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
   [ -f app/rector.php ] || cp -f bin/config/sample-rector.php app/rector.php
   [ -f app/phpstan.neon ] || cp -f bin/config/sample-phpstan.neon app/phpstan.neon
}
