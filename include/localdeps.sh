#!/usr/bin/env bash

# ------------------------------------------------------------------
# Gestion des dépendances locales (repos Git internes)
#
# Remplace temporairement une dépendance Composer publiée par un clone
# Git local, monté en "path" + symlink dans composer.json, puis permet
# de revenir à l'état d'origine (rollback).
#
# Prérequis hôte : git, jq
# Catalogue      : bin/localdeps.json                 ([{repo, package, path}, ...])
# État courant   : external/.localdeps.state.json     (dossier external/ gitignoré)
# ------------------------------------------------------------------

LOCALDEPS_CONFIG="./bin/localdeps.json"
LOCALDEPS_EXTERNAL_DIR="./external"
LOCALDEPS_STATE="$LOCALDEPS_EXTERNAL_DIR/.localdeps.state.json"

# --- Helpers -------------------------------------------------------

# Vérifie les prérequis hôte et l'existence du catalogue.
localdep_check_requirements() {
    command -v jq  >/dev/null 2>&1 || displayError "jq est requis sur l'hôte pour la commande localdep."
    command -v git >/dev/null 2>&1 || displayError "git est requis sur l'hôte pour la commande localdep."
    [[ -f "$LOCALDEPS_CONFIG" ]] || displayError "Catalogue introuvable : $LOCALDEPS_CONFIG"
}

# Initialise le fichier d'état (et le dossier external/) s'ils n'existent pas.
localdep_init_state() {
    mkdir -p "$LOCALDEPS_EXTERNAL_DIR"
    [[ -f "$LOCALDEPS_STATE" ]] || echo '{}' > "$LOCALDEPS_STATE"
}

# Chemin du composer.json de l'application.
composer_json() {
    echo "$APP__SYMFONY_APP_PATH/composer.json"
}

# Transformation jq atomique en place : jq_inplace <fichier> <args... filtre>
jq_inplace() {
    local file=$1; shift
    local tmp; tmp=$(mktemp)
    if jq "$@" "$file" > "$tmp"; then
        mv "$tmp" "$file"
    else
        rm -f "$tmp"
        displayError "Échec de la transformation jq sur $file"
    fi
}

# Retourne l'entrée catalogue (JSON) d'un package, vide si absent.
localdep_entry() {
    jq -c --arg pkg "$1" '.[] | select(.package==$pkg)' "$LOCALDEPS_CONFIG"
}

# --- composer.json : repo "path" & require -------------------------

# Ajoute le repo "path" en tête de repositories (dédoublonné).
localdep_add_path_repo() {
    local path=$1 cj; cj=$(composer_json)
    jq_inplace "$cj" --arg url "$path" 'del(.repositories[] | select(.url==$url))'
    jq_inplace "$cj" --arg url "$path" \
        '.repositories = [ {type:"path", url:$url, options:{symlink:true}} ] + .repositories'
}

# Retire le repo "path" correspondant (match exact sur l'URL).
localdep_remove_path_repo() {
    jq_inplace "$(composer_json)" --arg url "$1" 'del(.repositories[] | select(.url==$url))'
}

# Fixe require[package] à une chaîne (ex. @dev).
localdep_require_string() {
    jq_inplace "$(composer_json)" --arg pkg "$1" --arg v "$2" '.require[$pkg]=$v'
}

# Restaure require[package] depuis un JSON ("x.y.*" ou null → suppression).
localdep_restore_require() {
    local package=$1 json=$2
    if [[ "$json" == "null" ]]; then
        jq_inplace "$(composer_json)" --arg pkg "$package" 'del(.require[$pkg])'
    else
        jq_inplace "$(composer_json)" --arg pkg "$package" --argjson v "$json" '.require[$pkg]=$v'
    fi
}

# --- Fichier d'état ------------------------------------------------

# Enregistre l'état d'origine d'un package.
# $1 package  $2 contrainte(JSON)  $3 hadPath(true/false)  $4 path  $5 dir
localdep_state_save() {
    localdep_init_state
    jq_inplace "$LOCALDEPS_STATE" \
        --arg pkg "$1" --argjson c "$2" --argjson hp "$3" --arg p "$4" --arg d "$5" \
        '.[$pkg]={constraint:$c, hadPath:$hp, path:$p, dir:$d}'
}

localdep_state_has() {
    [[ -f "$LOCALDEPS_STATE" ]] && jq -e --arg pkg "$1" 'has($pkg)' "$LOCALDEPS_STATE" >/dev/null 2>&1
}

localdep_state_del() {
    jq_inplace "$LOCALDEPS_STATE" --arg pkg "$1" 'del(.[$pkg])'
}

# --- Git -----------------------------------------------------------

localdep_clone() {
    local repo=$1 dir=$2 branch=$3
    if [[ -d "$dir" ]]; then
        echo "→ Répertoire $dir déjà présent, suppression."
        rm -rf "$dir"
    fi
    echo "→ Clonage de $repo dans $dir"
    git clone "$repo" "$dir" || displayError "Échec du clonage de $repo"
    echo "→ Checkout de la branche $branch"
    git -C "$dir" checkout "$branch" || displayError "Branche '$branch' introuvable dans $repo"
}

# ------------------------------------------------------------------
# localdep list — catalogue + état
# ------------------------------------------------------------------
localdep_list() {
    localdep_check_requirements
    localdep_init_state
    echo "Repos locaux disponibles (catalogue $LOCALDEPS_CONFIG) :"
    local i=1 pkg tag
    while IFS= read -r pkg; do
        if localdep_state_has "$pkg"; then tag="  [ACTIF]"; else tag=""; fi
        printf "  %d) %-26s%s\n" "$i" "$pkg" "$tag"
        i=$((i + 1))
    done < <(jq -r '.[].package' "$LOCALDEPS_CONFIG")
}

# ------------------------------------------------------------------
# localdep status — dépendances locales actives
# ------------------------------------------------------------------
localdep_status() {
    localdep_init_state
    if [[ "$(jq 'length' "$LOCALDEPS_STATE")" -eq 0 ]]; then
        echo "Aucune dépendance locale active."
        return 0
    fi
    echo "Dépendances locales actives :"
    jq -r 'to_entries[] | "  - \(.key)  (origine: \(.value.constraint // "absent"), clone: \(.value.dir))"' \
        "$LOCALDEPS_STATE"
}

# ------------------------------------------------------------------
# localdep add [package] [branch] — active une dépendance locale
# ------------------------------------------------------------------
localdep_add() {
    localdep_check_requirements
    localdep_init_state

    local package=${1:-}
    local branch=${2:-develop}

    # Sélection interactive si aucun package fourni.
    if [[ -z "$package" ]]; then
        echo "Sélectionne un repo local à activer :"
        local choices
        mapfile -t choices < <(jq -r '.[].package' "$LOCALDEPS_CONFIG")
        select package in "${choices[@]}"; do
            [[ -n "$package" ]] && break
            echo "Choix invalide."
        done
    fi

    local entry; entry=$(localdep_entry "$package")
    [[ -n "$entry" ]] || displayError "Package '$package' absent du catalogue ($LOCALDEPS_CONFIG)."
    localdep_state_has "$package" && \
        displayError "'$package' est déjà en dépendance locale. Fais un 'bin/app localdep rollback $package' d'abord."

    local repo path dir cj
    repo=$(echo "$entry" | jq -r '.repo')
    path=$(echo "$entry" | jq -r '.path')
    dir="$LOCALDEPS_EXTERNAL_DIR/$(basename "$repo" .git)"
    cj=$(composer_json)

    echo "== Activation de la dépendance locale $package (branche $branch) =="

    # 1. Snapshot de l'état d'origine (contrainte require + présence du repo path).
    local orig_constraint orig_haspath
    orig_constraint=$(jq -c --arg pkg "$package" '.require[$pkg] // null' "$cj")
    orig_haspath=$(jq --arg p "$path" '[.repositories[]? | select(.url==$p)] | length > 0' "$cj")
    localdep_state_save "$package" "$orig_constraint" "$orig_haspath" "$path" "$dir"

    # 2. Clone local.
    localdep_clone "$repo" "$dir" "$branch"

    # 3. composer.json : repo path (en tête) + require @dev.
    localdep_add_path_repo "$path"
    localdep_require_string "$package" "@dev"

    # 4. Résolution Composer (symlink vers le clone local).
    echo "→ composer update $package"
    dockerRuncli composer update "$package" --with-all-dependencies \
        || displayError "Échec de composer update pour $package"

    echo "✅ $package est désormais lié en local ($dir, branche $branch)."
}

# ------------------------------------------------------------------
# localdep rollback [package] — restaure l'état d'origine
#   sans package : rollback de TOUTES les dépendances locales actives
# ------------------------------------------------------------------
localdep_rollback() {
    localdep_check_requirements
    localdep_init_state

    local target=${1:-}
    local packages=()

    if [[ -n "$target" ]]; then
        localdep_state_has "$target" || displayError "'$target' n'est pas une dépendance locale active."
        packages=("$target")
    else
        mapfile -t packages < <(jq -r 'keys[]' "$LOCALDEPS_STATE")
        if [[ ${#packages[@]} -eq 0 ]]; then
            echo "Aucune dépendance locale active, rien à faire."
            return 0
        fi
        echo "Rollback de ${#packages[@]} dépendance(s) locale(s) : ${packages[*]}"
    fi

    local package
    for package in "${packages[@]}"; do
        echo "== Rollback de $package =="
        local constraint haspath path dir
        constraint=$(jq -c --arg pkg "$package" '.[$pkg].constraint' "$LOCALDEPS_STATE")
        haspath=$(jq -r --arg pkg "$package" '.[$pkg].hadPath' "$LOCALDEPS_STATE")
        path=$(jq -r --arg pkg "$package" '.[$pkg].path' "$LOCALDEPS_STATE")
        dir=$(jq -r --arg pkg "$package" '.[$pkg].dir' "$LOCALDEPS_STATE")

        # 1. Retirer le repo path (sauf s'il préexistait à l'origine).
        [[ "$haspath" == "true" ]] || localdep_remove_path_repo "$path"

        # 2. Restaurer la contrainte require d'origine (ou retirer le package).
        if [[ "$constraint" == "null" ]]; then
            echo "→ composer remove $package"
            dockerRuncli composer remove "$package" || displayError "Échec de composer remove pour $package"
        else
            localdep_restore_require "$package" "$constraint"
            echo "→ composer update $package (restauration de $constraint)"
            dockerRuncli composer update "$package" --with-all-dependencies \
                || displayError "Échec de composer update pour $package"
        fi

        # 3. Supprimer le clone local.
        if [[ -n "$dir" && "$dir" != "null" && -d "$dir" ]]; then
            echo "→ Suppression du clone local $dir"
            rm -rf "$dir"
        fi

        # 4. Purger l'état.
        localdep_state_del "$package"
        echo "✅ $package restauré."
    done
}

# ------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------
localdep_usage() {
    cat <<'EOF'
Usage : bin/app localdep <commande>

  list                     Liste les repos locaux disponibles (et leur état).
  status                   Affiche les dépendances locales actives.
  add [package] [branch]   Active une dépendance locale : clone le repo, la lie en
                           "path"/symlink et met à jour Composer, après snapshot de
                           l'état d'origine. Sans package : menu interactif.
                           Branche par défaut : develop.
  rollback [package]       Restaure l'état d'origine d'un package. Sans package :
                           rollback de TOUTES les dépendances locales actives.

Catalogue des repos : bin/localdeps.json
EOF
}
