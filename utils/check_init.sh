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

# === Vérification de la date ===
check_date() {
    if [ ! -f "${LAST_DATE_CHECK_FILE}" ]; then
        error "Date de dernière vérification non trouvée"
    fi
    
    last_check=$(cat "${LAST_DATE_CHECK_FILE}")
    current_date=$(LC_TIME=fr_FR.UTF-8 date "+%A %d %B %Y")
    last_check_date=$(echo "$last_check" | cut -d',' -f1)
    
    if [ "$current_date" != "$last_check_date" ]; then
        warning "Dernière vérification : $last_check"
        warning "Une nouvelle vérification est recommandée"
        return 1
    else
        success "Vérification à jour : $last_check"
        return 0
    fi
}

# === Vérification des fichiers essentiels ===
check_files() {
    local missing=0
    
    # Vérification de config.env
    if [ ! -f "${CURSOR_CONFIG_PATH}" ]; then
        error "config.env manquant"
    else
        success "config.env présent"
    fi
    
    # Vérification de .cursorrules
    if [ ! -f "${CURSOR_RULES_FILE}" ]; then
        error ".cursorrules manquant"
    else
        success ".cursorrules présent"
    fi
    
    # Vérification de l'analyse du workspace
    if [ ! -f "${WORKSPACE_ANALYSIS_FILE}" ]; then
        warning "Analyse du workspace manquante"
        ((missing++))
    else
        success "Analyse du workspace présente"
    fi
    
    return $missing
}

# === Vérification de la structure ===
check_structure() {
    local missing=0
    
    # Vérification des composants du projet
    check_component() {
        local path="$1"
        local name="$2"
        if [ ! -d "$path" ]; then
            warning "Composant '$name' manquant"
            return 1
        else
            success "Composant '$name' présent"
            return 0
        fi
    }
    
    check_component "$PROJECT_1_PATH" "$PROJECT_NAME_1" || ((missing++))
    check_component "$PROJECT_2_PATH" "$PROJECT_NAME_2" || ((missing++))
    check_component "$PROJECT_3_PATH" "$PROJECT_NAME_3" || ((missing++))
    check_component "$PROJECT_4_PATH" "$PROJECT_NAME_4" || ((missing++))
    
    # Vérification des dossiers de configuration
    if [ ! -d "$CURSOR_TEMPLATE_PATH" ]; then
        warning "Templates Cursor manquants"
        ((missing++))
    else
        success "Templates Cursor présents"
    fi
    
    return $missing
}

# === Fonction principale ===
main() {
    echo "========================================"
    echo "🔍 VÉRIFICATION DE L'INITIALISATION"
    echo "========================================"
    
    local status=0
    
    # 1. Vérification des fichiers
    echo -e "\n=== Fichiers Essentiels ==="
    check_files
    status=$((status + $?))
    
    # 2. Vérification de la date
    echo -e "\n=== Date de Vérification ==="
    check_date
    status=$((status + $?))
    
    # 3. Vérification de la structure
    echo -e "\n=== Structure du Workspace ==="
    check_structure
    status=$((status + $?))
    
    echo -e "\n========================================"
    if [ $status -eq 0 ]; then
        success "Tout est en ordre ✨"
        exit 0
    else
        warning "Des vérifications sont nécessaires ($status problèmes détectés)"
        info "Exécutez ${INIT_SCRIPT} pour une vérification complète"
        exit 1
    fi
}

# Exécution
main