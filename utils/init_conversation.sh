#!/bin/bash

# === Configuration initiale ===
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_FILE="${SCRIPT_DIR}/../config.env"

# === Chargement de la configuration ===
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ ERREUR : config.env non trouvé${NC}"
    exit 1
fi

source "$CONFIG_FILE"

# === Navigation vers la racine du workspace ===
cd "$WORKSPACE_ROOT" || {
    echo -e "${RED}❌ ERREUR : Impossible de naviguer vers $WORKSPACE_ROOT${NC}"
    exit 1
}

# === Couleurs pour les messages ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# === Fonctions utilitaires ===
error() {
    echo -e "${RED}❌ ERREUR : $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# === Variables pour les arguments ===
CREATE_STRUCTURE=false

# === Parsing des arguments ===
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --create) CREATE_STRUCTURE=true ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --create    Crée automatiquement la structure du workspace si vide"
                echo "  --help, -h  Affiche cette aide"
                exit 0
                ;;
            *)
                error "Option inconnue : $1"
                ;;
        esac
        shift
    done
}

# === Fonction pour créer la structure du workspace ===
create_workspace_structure() {
    echo -e "\n=== CRÉATION DE LA STRUCTURE DU WORKSPACE ==="
    
    # Vérification si le workspace est vide
    local files_count=$(ls -A "$WORKSPACE_ROOT" | grep -v "cursor-template" | wc -l)
    if [ "$files_count" -gt 0 ]; then
        info "Le workspace n'est pas vide, structure non créée"
        return 0
    fi
    
    # Création automatique si --create est utilisé
    if [ "$CREATE_STRUCTURE" = true ]; then
        info "Création automatique de la structure du workspace..."
    else
        info "Le workspace est vide. Utilisez --create pour créer la structure automatiquement"
        return 0
    fi
    
    # Création des dossiers
    echo -e "\nCréation des dossiers :"
    
    create_project() {
        local path=$1
        local name=$2
        local type=$3
        
        if [ ! -d "$path" ]; then
            mkdir -p "$path"
            success "✓ Créé : $name ($type)"
            
            # Initialisation spécifique selon le type
            case "$type" in
                "$COMPONENT_TYPE_FRONTEND")
                    touch "$path/package.json"
                    touch "$path/next.config.js"
                    mkdir -p "$path/src/app"
                    mkdir -p "$path/public"
                    ;;
                "$COMPONENT_TYPE_BACKEND"|"$COMPONENT_TYPE_CORE")
                    touch "$path/requirements.txt"
                    touch "$path/README.md"
                    mkdir -p "$path/src"
                    mkdir -p "$path/tests"
                    ;;
                "$COMPONENT_TYPE_DOC")
                    touch "$path/README.md"
                    mkdir -p "$path/docs"
                    ;;
            esac
        else
            warning "! Existe déjà : $name"
        fi
    }
    
    create_project "$PROJECT_1_PATH" "$PROJECT_NAME_1" "$COMPONENT_TYPE_FRONTEND"
    create_project "$PROJECT_2_PATH" "$PROJECT_NAME_2" "$COMPONENT_TYPE_BACKEND"
    create_project "$PROJECT_3_PATH" "$PROJECT_NAME_3" "$COMPONENT_TYPE_CORE"
    create_project "$PROJECT_4_PATH" "$PROJECT_NAME_4" "$COMPONENT_TYPE_DOC"
    
    echo -e "\n✨ Structure du workspace créée avec succès !"
    echo -e "📝 N'oubliez pas d'initialiser Git dans chaque projet si nécessaire"
}

# === Exécution principale ===
main() {
    # Parser les arguments en premier
    parse_arguments "$@"
    
    echo "=== INITIALISATION DE LA CONVERSATION ==="
    
    # Vérification et création de la structure si nécessaire
    create_workspace_structure
    
    # Vérification de l'environnement
    check_script="$SCRIPT_DIR/check_workspace_path.sh"
    if [ ! -f "$check_script" ]; then
        error "Script de vérification non trouvé : $check_script"
    fi
    
    if [ ! -x "$check_script" ]; then
        chmod +x "$check_script"
    fi
    
    info "Vérification de l'environnement..."
    if ! "$check_script"; then
        error "La vérification de l'environnement a échoué"
    fi
    success "Environnement vérifié"
    
    # === Fonction pour vérifier la version Python ===
    check_python_version() {
        local project_path=$1
        local project_name=$2
        local reason=""
        
        if [ -f "$project_path/requirements.txt" ]; then
            reason="requirements.txt trouvé"
        elif [ -f "$project_path/pyproject.toml" ]; then
            reason="pyproject.toml trouvé"
        fi
        
        if [ ! -z "$reason" ]; then
            info "Python ($project_name) - $reason"
            
            if [ -d "$project_path/venv" ] && [ -f "$project_path/venv/bin/python" ]; then
                local version=$("$project_path/venv/bin/python" -V 2>/dev/null | cut -d' ' -f2 || echo "non accessible")
                success "Version installée : $version (venv)"
            elif [ -d "$project_path/.venv" ] && [ -f "$project_path/.venv/bin/python" ]; then
                local version=$("$project_path/.venv/bin/python" -V 2>/dev/null | cut -d' ' -f2 || echo "non accessible")
                success "Version installée : $version (.venv)"
            else
                warning "Pas d'environnement virtuel"
            fi
            info "Version configurée : ${PYTHON_VERSION}"
        fi
    }
    
    # === Fonction pour vérifier Node.js ===
    check_nodejs_version() {
        local project_path=$1
        local project_name=$2
        local reason=""
        
        if [ -f "$project_path/package.json" ]; then
            reason="package.json trouvé"
        elif [ -f "$project_path/next.config.js" ] || [ -f "$project_path/next.config.mjs" ]; then
            reason="configuration Next.js trouvée"
        fi
        
        if [ ! -z "$reason" ]; then
            info "Node.js ($project_name) - $reason"
            NODE_CURRENT=$(node -v 2>/dev/null || echo "non installé")
            success "Version installée : $NODE_CURRENT"
            info "Version configurée : ${NODE_VERSION}"
            
            if [ -f "$project_path/pnpm-lock.yaml" ] || [ -f "$project_path/node_modules/.pnpm/lock.yaml" ]; then
                PNPM_CURRENT=$(pnpm -v 2>/dev/null || echo "non installé")
                success "pnpm installé : $PNPM_CURRENT"
                info "pnpm configuré : ${PNPM_VERSION}"
            fi
        fi
    }
    
    # === Vérification des versions ===
    echo -e "\n=== VÉRIFICATION DES VERSIONS ==="
    
    check_project() {
        local path="$1"
        local type="$2"
        local name="$3"
        
        echo -e "\n--- $name ---"
        case "$type" in
            "$COMPONENT_TYPE_FRONTEND")
                check_nodejs_version "$path" "$name"
                ;;
            "$COMPONENT_TYPE_BACKEND"|"$COMPONENT_TYPE_CORE")
                check_python_version "$path" "$name"
                ;;
        esac
    }
    
    check_project "$PROJECT_1_PATH" "$COMPONENT_TYPE_FRONTEND" "$PROJECT_NAME_1"
    check_project "$PROJECT_2_PATH" "$COMPONENT_TYPE_BACKEND" "$PROJECT_NAME_2"
    check_project "$PROJECT_3_PATH" "$COMPONENT_TYPE_CORE" "$PROJECT_NAME_3"
    check_project "$PROJECT_4_PATH" "$COMPONENT_TYPE_DOC" "$PROJECT_NAME_4"
    
    # === Vérification des chemins ===
    check_path() {
        local path=$1
        local name=$2
        
        info "Vérification de $name ($path)"
        if [ ! -d "$path" ]; then
            warning "Dossier non trouvé"
            return
        fi
        
        local perms=""
        [ ! -r "$path" ] && perms="lecture "
        [ ! -w "$path" ] && perms="${perms}écriture "
        [ ! -x "$path" ] && perms="${perms}exécution"
        
        if [ -z "$perms" ]; then
            success "Permissions OK"
        else
            warning "Permissions manquantes : $perms"
        fi
    }
    
    echo -e "\n=== VÉRIFICATION DES CHEMINS ==="
    check_path "${CURSOR_TEMPLATE_PATH}" "${COMPONENT_TYPE_CONFIG}"
    
    # === Vérification des fichiers de configuration ===
    echo -e "\n=== VÉRIFICATION DES FICHIERS ==="
    [ -f "${CURSOR_RULES_FILE}" ] && success ".cursorrules trouvé" || warning ".cursorrules non trouvé"
    [ -f "${CURSOR_CONFIG_FILE}" ] && success "cursorconfig.json trouvé" || warning "cursorconfig.json non trouvé"
    
    # === Mise à jour de la date ===
    echo -e "\n=== MISE À JOUR DE LA DATE ==="
    current_date=$(LC_TIME=fr_FR.UTF-8 date "+%A %d %B %Y, %H:%M")
    echo "$current_date"
    echo "$current_date" > "${LAST_DATE_CHECK_FILE}"
    
    # === Analyse du workspace ===
    echo -e "\n=== ANALYSE DU WORKSPACE ==="
    
    # Sauvegarder l'ancienne analyse si elle existe
    if [ -f "${WORKSPACE_ANALYSIS_FILE}" ]; then
        mv "${WORKSPACE_ANALYSIS_FILE}" "${WORKSPACE_ANALYSIS_PREVIOUS}"
    fi
    
    # Créer la nouvelle analyse
    if ls -R . > "${WORKSPACE_ANALYSIS_FILE}" 2>/dev/null; then
        success "Structure du projet sauvegardée"
    else
        warning "Impossible de sauvegarder la structure"
    fi
    
    echo -e "\n=== INITIALISATION TERMINÉE ==="
    success "Vous pouvez maintenant commencer la conversation" 
}

# Passer les arguments à main
main "$@" 