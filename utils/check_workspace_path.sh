#!/bin/bash

# === Configuration initiale ===
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_PATH="${SCRIPT_DIR}/../config.env"

# === Chargement de la configuration ===
if [[ ! -f "$CONFIG_PATH" ]]; then
    echo -e "${RED}❌ ERREUR : config.env non trouvé${NC}"
    exit 1
fi

source "$CONFIG_PATH"

# === Navigation vers la racine du workspace ===
cd "$WORKSPACE_ROOT" || {
    echo -e "${RED}❌ ERREUR : Impossible de naviguer vers $WORKSPACE_ROOT${NC}"
    exit 1
}

# === Variables globales ===
# Couleurs pour les messages
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

# === Vérification des outils ===
check_tool() {
    local tool=$1
    local version_cmd=$2
    if command -v $tool &> /dev/null; then
        if [ -n "$version_cmd" ]; then
            success "$tool : $(eval $version_cmd 2>&1 | head -n 1)"
        else
            success "$tool : installé"
        fi
        return 0
    else
        warning "$tool : non installé"
        return 1
    fi
}

# === Vérification des ressources ===
check_resources() {
    echo -e "\n=== Ressources Système ==="
    
    # Mémoire
    case "${OS_NAME}" in
        macOS)
            MEMORY=$(sysctl -n hw.memsize 2>/dev/null)
            MEMORY_GB=$((MEMORY / 1024 / 1024 / 1024))
            ;;
        Linux)
            MEMORY=$(free -b | awk '/Mem:/ {print $2}')
            MEMORY_GB=$((MEMORY / 1024 / 1024 / 1024))
            ;;
    esac
    echo "Mémoire RAM : ${MEMORY_GB}GB"
    if [ "${MEMORY_GB}" -lt "${MIN_MEMORY_GB}" ]; then
        warning "Mémoire RAM limitée (minimum recommandé : ${MIN_MEMORY_GB}GB)"
    else
        success "Mémoire RAM suffisante"
    fi

    # Espace disque
    DISK_SPACE=$(df -h . | awk 'NR==2 {print $4}')
    echo "Espace disque disponible : ${DISK_SPACE}"
    
    # Convertir en GB pour la comparaison
    DISK_GB=$(echo $DISK_SPACE | sed 's/[^0-9.]//g')
    DISK_UNIT=$(echo $DISK_SPACE | sed 's/[0-9.]//g')
    case $DISK_UNIT in
        "Ti"|"TiB") DISK_GB=$(echo "$DISK_GB * 1024" | bc) ;;
        "Gi"|"GiB") DISK_GB=$DISK_GB ;;
        "Mi"|"MiB") DISK_GB=$(echo "$DISK_GB / 1024" | bc) ;;
    esac
    
    MIN_GB=$(echo $MIN_DISK_SPACE | sed 's/[^0-9.]//g')
    if (( $(echo "$DISK_GB < $MIN_GB" | bc -l) )); then
        warning "Espace disque limité (minimum recommandé : ${MIN_DISK_SPACE})"
    else
        success "Espace disque suffisant"
    fi

    # CPU
    case "${OS_NAME}" in
        macOS)
            CPU_INFO=$(sysctl -n machdep.cpu.brand_string)
            CPU_CORES=$(sysctl -n hw.ncpu)
            ;;
        Linux)
            CPU_INFO=$(grep "model name" /proc/cpuinfo | head -n 1 | cut -d ":" -f2 | sed 's/^[ \t]*//')
            CPU_CORES=$(nproc)
            ;;
    esac
    echo "CPU : ${CPU_INFO}"
    echo "Nombre de cœurs : ${CPU_CORES}"
    if [ "${CPU_CORES}" -lt "${MIN_CPU_CORES}" ]; then
        warning "Nombre de cœurs limité (minimum recommandé : ${MIN_CPU_CORES})"
    else
        success "Nombre de cœurs suffisant"
    fi
}

# === Vérification des outils requis ===
check_required_tools() {
    echo -e "\n=== Outils Requis ==="
    
    # Outils de base
    check_tool "git" "git --version"
    check_tool "node" "node --version"
    check_tool "npm" "npm --version"
    
    # Python système (juste vérifier la présence)
    if command -v python3 &> /dev/null; then
        success "python3 : disponible ($(python3 --version 2>&1))"
    else
        warning "python3 : non installé"
    fi
    if command -v pip3 &> /dev/null; then
        success "pip3 : disponible ($(pip3 --version 2>&1 | cut -d' ' -f1,2))"
    else
        warning "pip3 : non installé"
    fi

    # Outils spécifiques à l'OS
    case "${OS_NAME}" in
        macOS)
            echo -e "\n=== Outils macOS ==="
            check_tool "brew" "brew --version"
            if xcode-select -p &>/dev/null; then
                success "Command Line Tools : installé"
            else
                warning "Command Line Tools : non installé"
                info "Installer avec : xcode-select --install"
            fi
            ;;
        Linux)
            echo -e "\n=== Outils Linux ==="
            check_tool "gcc" "gcc --version"
            check_tool "make" "make --version"
            if ! dpkg -l build-essential &>/dev/null; then
                warning "build-essential : non installé"
                info "Installer avec : sudo apt install build-essential"
            fi
            ;;
    esac
}

# === Détection de l'environnement ===
detect_environment() {
    echo -e "\n=== Détection de l'Environnement ==="
    
    # Détection du système d'exploitation
    OS="$(uname -s)"
    case "${OS}" in
        Darwin*)
            OS_NAME="macOS"
            if [[ $(uname -m) == 'arm64' ]]; then
                ARCH="Apple Silicon"
            else
                ARCH="Intel"
            fi
            OS_VERSION=$(sw_vers -productVersion)
            ;;
        Linux*)
            OS_NAME="Linux"
            ARCH=$(uname -m)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                DISTRO="$NAME $VERSION_ID"
            else
                DISTRO="Distribution inconnue"
            fi
            ;;
        MINGW*|CYGWIN*|MSYS*)
            OS_NAME="Windows"
            ARCH=$(uname -m)
            if grep -q Microsoft /proc/version 2>/dev/null; then
                DISTRO="WSL2"
            else
                DISTRO="Windows natif"
            fi
            ;;
        *)
            OS_NAME="OS inconnu"
            ARCH=$(uname -m)
            ;;
    esac

    # Affichage des informations de base
    echo "Système : $OS_NAME"
    echo "Architecture : $ARCH"
    case "${OS_NAME}" in
        macOS)
            echo "Version : $OS_VERSION"
            ;;
        Linux)
            echo "Distribution : $DISTRO"
            ;;
        Windows)
            echo "Environnement : $DISTRO"
            ;;
    esac

    # Vérification de la compatibilité
    case "${OS_NAME}" in
        macOS|Linux)
            success "Environnement compatible"
            ;;
        Windows)
            if [[ "$DISTRO" == "WSL2" ]]; then
                success "Environnement compatible (WSL2)"
            else
                warning "Windows natif détecté. Veuillez utiliser WSL2"
            fi
            ;;
        *)
            error "Environnement non supporté"
            ;;
    esac

    # Vérification des ressources et outils
    check_resources
    check_required_tools
}

# === Vérification de la structure ===
check_structure() {
    echo -e "\n=== Vérification de la structure ==="
    local missing=0
    
    # Fonction pour vérifier un composant
    check_component() {
        local path="$1"
        local name="$2"
        local type="$3"
        if [ -d "$path" ]; then
            success "Composant '$name' trouvé"
            if [ -r "$path" ] && [ -w "$path" ]; then
                success "Permissions OK pour '$name'"
                # Vérifier le venv si c'est un projet Python
                if [ "$type" = "$COMPONENT_TYPE_BACKEND" ] || [ "$type" = "$COMPONENT_TYPE_CORE" ]; then
                    local venv_path=""
                    if [ -d "$path/venv" ]; then
                        venv_path="$path/venv"
                    elif [ -d "$path/.venv" ]; then
                        venv_path="$path/.venv"
                    fi
                    
                    if [ ! -z "$venv_path" ]; then
                        success "Environnement virtuel trouvé pour '$name'"
                        if [ -f "$venv_path/bin/python" ]; then
                            local venv_version=$("$venv_path/bin/python" -V 2>&1 | cut -d' ' -f2)
                            info "Version Python dans venv : $venv_version"
                            if [ "$venv_version" = "$PYTHON_VERSION" ]; then
                                success "Version Python correcte dans venv"
                            else
                                warning "Version Python différente dans venv ($venv_version ≠ $PYTHON_VERSION)"
                            fi
                        fi
                    else
                        warning "Pas d'environnement virtuel pour '$name' (requis pour projets Python)"
                    fi
                fi
                return 0
            else
                error "Permissions insuffisantes pour '$name'"
                return 1
            fi
        else
            error "Composant '$name' manquant"
            return 1
        fi
    }
    
    # Vérification des composants du projet
    check_component "$PROJECT_1_PATH" "$PROJECT_NAME_1" "$COMPONENT_TYPE_FRONTEND" || ((missing++))
    check_component "$PROJECT_2_PATH" "$PROJECT_NAME_2" "$COMPONENT_TYPE_BACKEND" || ((missing++))
    check_component "$PROJECT_3_PATH" "$PROJECT_NAME_3" "$COMPONENT_TYPE_CORE" || ((missing++))
    check_component "$PROJECT_4_PATH" "$PROJECT_NAME_4" "$COMPONENT_TYPE_DOC" || ((missing++))
    
    # Vérification des dossiers de configuration
    if [ -d "$CURSOR_TEMPLATE_PATH" ]; then
        success "Templates Cursor trouvés"
    else
        error "Templates Cursor manquants"
        ((missing++))
    fi
    
    return $missing
}

# === Analyse du workspace ===
analyze_workspace() {
    echo -e "\n=== Analyse du Workspace ==="
    
    # Nettoyer les anciennes analyses (garder uniquement la dernière)
    if [ -f "$SCRIPT_DIR/workspace_analysis.previous.old" ]; then
        rm "$SCRIPT_DIR/workspace_analysis.previous.old"
    fi
    
    # Faire tourner les fichiers d'analyse
    if [ -f "$SCRIPT_DIR/workspace_analysis.previous" ]; then
        mv "$SCRIPT_DIR/workspace_analysis.previous" "$SCRIPT_DIR/workspace_analysis.previous.old"
    fi
    if [ -f "$SCRIPT_DIR/workspace_analysis" ]; then
        mv "$SCRIPT_DIR/workspace_analysis" "$SCRIPT_DIR/workspace_analysis.previous"
    fi
    
    # Sauvegarder l'état actuel
    if ls -R . > "$SCRIPT_DIR/workspace_analysis" 2>/dev/null; then
        success "Structure du workspace sauvegardée"
    else
        warning "Impossible de sauvegarder la structure"
        return 1
    fi
    
    # Détecter les changements si un état précédent existe
    if [ -f "$SCRIPT_DIR/workspace_analysis.previous" ]; then
        echo -e "\n=== Détection des Changements ==="
        
        # Comparer les fichiers pour détecter les nouveaux dossiers
        new_dirs=$(diff "$SCRIPT_DIR/workspace_analysis.previous" "$SCRIPT_DIR/workspace_analysis" | grep "^> ./" | cut -d' ' -f2-)
        
        if [ ! -z "$new_dirs" ]; then
            warning "Nouveaux dossiers détectés :"
            echo "$new_dirs" | while read dir; do
                info "• $dir"
            done
            echo "Utilisez 'check_init.sh' pour mettre à jour la configuration"
        else
            success "Aucun changement structurel détecté"
        fi
    fi
    
    return 0
}

# === Fonction principale ===
main() {
    # En-tête
    echo "========================================"
    echo "🔍 Vérification de l'Environnement"
    echo "========================================"
    echo "Date : $(date '+%A %d %B %Y, %H:%M')"
    echo "----------------------------------------"

    # Détection de l'environnement
    detect_environment

    # Vérification de la structure
    check_structure

    # Analyse du workspace
    analyze_workspace

    echo -e "\n========================================"
    echo "✅ Vérification terminée"
    echo "========================================"
}

# Exécution
main