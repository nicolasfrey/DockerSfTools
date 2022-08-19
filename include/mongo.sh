#!/usr/bin/env bash

mongoDBReload () {
   systemCreateFolder "${APP__APPLICATION_FOLDER}"
   mongoInitDB
   mongoLoadFixtures
}

mongoInitDB () {

#   dockerRuncli bin/console doctrine:mongodb:schema:drop --full-database --force
#   dockerRuncli bin/console doctrine:mongodb:schema:update --force
#   dockerRuncli bin/console doctrine:mongodb:fixtures:load -n


   dockerRuncli bin/console doctrine:mongodb:schema:drop
   dockerRuncli bin/console doctrine:mongodb:schema:drop --dm=temp
   dockerRuncli bin/console doctrine:mongodb:schema:create || displayError
   dockerRuncli bin/console doctrine:mongodb:schema:create --dm=temp || displayError
}

mongoLoadFixtures () {
   dockerRuncli bin/console doctrine:mongodb:fixtures:load -n || displayError
}

mongoDBLoad () {
   displayMessage "${FUNCNAME[0]}, Not implemented yet"
}

mongoBackup () {
   displayMessage "${FUNCNAME[0]}, Not implemented yet"
}

mongoRestore () {
   displayMessage "${FUNCNAME[0]}, Not implemented yet"
}