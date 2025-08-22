#!/bin/bash

# Script de déploiement du router d'intents Bender
# Auteur: Assistant Bender
# Version: 1.0
# Date: 2025-08-22

set -euo pipefail

# Configuration
BENDER_DIR="/opt/bender"
LOGS_DIR="$BENDER_DIR/logs"
SERVICE_NAME="bender-intent.service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions utilitaires
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en tant que root (sudo)"
        exit 1
    fi
}

check_files() {
    local files=("intent_router.py" "bender-intent.service")
    
    for file in "${files[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
            log_error "Fichier manquant: $file"
            exit 1
        fi
    done
    
    log_success "Tous les fichiers requis sont présents"
}

install_dependencies() {
    log_info "Installation des dépendances Python..."
    
    # Mise à jour des packages système
    apt-get update
    
    # Installation des packages Python via apt
    apt-get install -y \
        python3-paho-mqtt \
        python3-requests \
        python3-full
    
    log_success "Dépendances installées"
}

setup_directories() {
    log_info "Configuration des répertoires..."
    
    # Création des répertoires si nécessaire
    mkdir -p "$BENDER_DIR"
    mkdir -p "$LOGS_DIR"
    
    # Permissions
    chown -R bender:bender "$BENDER_DIR"
    chmod 755 "$BENDER_DIR"
    chmod 755 "$LOGS_DIR"
    
    log_success "Répertoires configurés"
}

install_intent_router() {
    log_info "Installation du router d'intents..."
    
    # Arrêt du service s'il existe
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        log_info "Arrêt du service existant..."
        systemctl stop "$SERVICE_NAME"
    fi
    
    # Copie du script Python
    cp "$SCRIPT_DIR/intent_router.py" "$BENDER_DIR/"
    chown bender:bender "$BENDER_DIR/intent_router.py"
    chmod 755 "$BENDER_DIR/intent_router.py"
    
    # Installation du service systemd
    cp "$SCRIPT_DIR/bender-intent.service" "/etc/systemd/system/"
    
    # Rechargement de systemd
    systemctl daemon-reload
    
    log_success "Router d'intents installé"
}

test_intent_router() {
    log_info "Test du router d'intents..."
    
    # Test de syntaxe Python
    if python3 -m py_compile "$BENDER_DIR/intent_router.py"; then
        log_success "Syntaxe Python valide"
    else
        log_error "Erreur de syntaxe Python"
        return 1
    fi
    
    # Test d'import des modules
    if python3 -c "import sys; sys.path.insert(0, '$BENDER_DIR'); import intent_router"; then
        log_success "Imports Python OK"
    else
        log_error "Erreur d'import des modules"
        return 1
    fi
}

start_service() {
    log_info "Démarrage du service..."
    
    # Activation du service
    systemctl enable "$SERVICE_NAME"
    
    # Démarrage
    systemctl start "$SERVICE_NAME"
    
    # Vérification du statut
    sleep 3
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "Service $SERVICE_NAME démarré avec succès"
        
        # Affichage du statut
        systemctl status "$SERVICE_NAME" --no-pager -l
    else
        log_error "Échec du démarrage du service"
        log_info "Logs du service:"
        journalctl -u "$SERVICE_NAME" -n 20 --no-pager
        return 1
    fi
}

show_status() {
    log_info "État des services Bender:"
    
    echo
    echo "=== Services ==="
    systemctl status bender-audio.service --no-pager -l | head -10
    echo
    systemctl status bender-intent.service --no-pager -l | head -10
    
    echo
    echo "=== Logs récents ==="
    journalctl -u bender-intent.service -n 10 --no-pager
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --install       Installation complète du router d'intents
    --test-only     Test uniquement (sans installation)
    --restart       Redémarrage du service
    --status        Affichage du statut
    --logs          Affichage des logs
    --help          Affichage de cette aide

Exemples:
    sudo $0 --install
    sudo $0 --restart
    $0 --status

Fichiers requis dans le même répertoire:
    - intent_router.py
    - bender-intent.service

EOF
}

# Fonction principale
main() {
    local action="${1:-install}"
    
    case "$action" in
        "--install")
            check_root
            check_files
            install_dependencies
            setup_directories
            install_intent_router
            test_intent_router
            start_service
            show_status
            ;;
        "--test-only")
            check_files
            test_intent_router
            ;;
        "--restart")
            check_root
            log_info "Redémarrage du service $SERVICE_NAME..."
            systemctl restart "$SERVICE_NAME"
            sleep 3
            systemctl status "$SERVICE_NAME" --no-pager -l
            ;;
        "--status")
            show_status
            ;;
        "--logs")
            log_info "Logs du service $SERVICE_NAME:"
            journalctl -u "$SERVICE_NAME" -f --no-pager
            ;;
        "--help")
            show_help
            ;;
        *)
            log_info "Installation par défaut du router d'intents..."
            check_root
            check_files
            install_dependencies
            setup_directories
            install_intent_router
            test_intent_router
            start_service
            show_status
            ;;
    esac
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi