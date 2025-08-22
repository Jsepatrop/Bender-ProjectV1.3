#!/bin/bash
"""
Bender Audio Pipeline - Script d'installation
Installation complète du pipeline audio sur Raspberry Pi 5

Référence : Section 4.2.1 du Dossier de définition
Auteur : Assistant Bender DevOps
Version : 1.0
"""

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/bender_audio_install.log"
PYTHON_VENV="/opt/bender/venv"
SERVICE_USER="bender"

# Fonctions utilitaires
log_info() {
    echo "[INFO] $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo "[WARN] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté en tant que root"
        exit 1
    fi
}

check_pi5() {
    if ! grep -q "Raspberry Pi 5" /proc/cpuinfo; then
        log_warn "Ce script est optimisé pour Raspberry Pi 5"
    fi
}

install_system_deps() {
    log_info "Installation dépendances système..."
    
    apt-get update
    apt-get install -y \
        python3-dev \
        python3-pip \
        python3-venv \
        libasound2-dev \
        libportaudio2 \
        libportaudiocpp0 \
        portaudio19-dev \
        libffi-dev \
        libssl-dev \
        pkg-config \
        sox \
        alsa-utils
        
    log_info "Dépendances système installées"
}

setup_python_env() {
    log_info "Configuration environnement Python..."
    
    # Création répertoire
    mkdir -p "$(dirname "$PYTHON_VENV")"
    
    # Environnement virtuel
    if [[ ! -d "$PYTHON_VENV" ]]; then
        python3 -m venv "$PYTHON_VENV"
        log_info "Environnement virtuel créé: $PYTHON_VENV"
    fi
    
    # Activation et mise à jour pip
    source "$PYTHON_VENV/bin/activate"
    pip install --upgrade pip setuptools wheel
    
    # Installation dépendances audio
    if [[ -f "$SCRIPT_DIR/requirements_audio.txt" ]]; then
        pip install -r "$SCRIPT_DIR/requirements_audio.txt"
        log_info "Dépendances Python installées"
    else
        log_error "Fichier requirements_audio.txt introuvable"
        exit 1
    fi
}

setup_service_user() {
    log_info "Configuration utilisateur service..."
    
    # Création utilisateur bender si nécessaire
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd -r -s /bin/bash -d /opt/bender -m "$SERVICE_USER"
        log_info "Utilisateur $SERVICE_USER créé"
    fi
    
    # Ajout aux groupes audio
    usermod -a -G audio,pulse-access "$SERVICE_USER"
    
    # Permissions
    chown -R "$SERVICE_USER:$SERVICE_USER" /opt/bender
    chmod 755 /opt/bender
}

install_pipeline_script() {
    log_info "Installation script pipeline..."
    
    # Copie script principal
    if [[ -f "$SCRIPT_DIR/audio_pipeline.py" ]]; then
        cp "$SCRIPT_DIR/audio_pipeline.py" /opt/bender/
        chmod 755 /opt/bender/audio_pipeline.py
        chown "$SERVICE_USER:$SERVICE_USER" /opt/bender/audio_pipeline.py
        log_info "Script pipeline installé"
    else
        log_error "Script audio_pipeline.py introuvable"
        exit 1
    fi
    
    # Configuration par défaut
    cat > /opt/bender/audio_config.json << EOF
{
    "device_name": "hw:0,0",
    "sample_rate_in": 48000,
    "sample_rate_out": 16000,
    "channels": 2,
    "chunk_size": 1024,
    "vad_aggressiveness": 2,
    "aec_enabled": true,
    "eq_enabled": true,
    "limiter_enabled": true,
    "limiter_threshold": 0.8,
    "mqtt_broker": "192.168.1.138",
    "mqtt_port": 1883
}
EOF
    
    chown "$SERVICE_USER:$SERVICE_USER" /opt/bender/audio_config.json
    log_info "Configuration par défaut créée"
}

create_systemd_service() {
    log_info "Création service systemd..."
    
    cat > /etc/systemd/system/bender-audio.service << EOF
[Unit]
Description=Bender Audio Pipeline
After=network.target sound.target
Wants=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=/opt/bender
Environment=PATH=$PYTHON_VENV/bin
ExecStart=$PYTHON_VENV/bin/python /opt/bender/audio_pipeline.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Sécurité
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/bender /tmp

[Install]
WantedBy=multi-user.target
EOF
    
    # Rechargement systemd
    systemctl daemon-reload
    systemctl enable bender-audio.service
    
    log_info "Service systemd créé et activé"
}

test_audio_devices() {
    log_info "Test périphériques audio..."
    
    # Vérification carte son
    if aplay -l | grep -q "card 0"; then
        log_info "✅ Carte audio détectée"
    else
        log_error "❌ Aucune carte audio détectée"
        return 1
    fi
    
    # Test capture rapide
    if sudo -u "$SERVICE_USER" arecord -D hw:0,0 -f S32_LE -r 48000 -c 2 -d 1 /tmp/test_capture.wav 2>/dev/null; then
        log_info "✅ Capture audio fonctionnelle"
        rm -f /tmp/test_capture.wav
    else
        log_error "❌ Échec test capture"
        return 1
    fi
    
    # Test lecture rapide
    if sudo -u "$SERVICE_USER" sox -n -r 48000 -c 2 -b 32 /tmp/test_tone.wav synth 0.5 sine 440 2>/dev/null && \
       sudo -u "$SERVICE_USER" aplay -D hw:0,0 /tmp/test_tone.wav 2>/dev/null; then
        log_info "✅ Lecture audio fonctionnelle"
        rm -f /tmp/test_tone.wav
    else
        log_error "❌ Échec test lecture"
        return 1
    fi
}

test_pipeline() {
    log_info "Test pipeline audio..."
    
    # Test import Python
    if sudo -u "$SERVICE_USER" "$PYTHON_VENV/bin/python" -c "import sounddevice, webrtcvad, paho.mqtt.client; print('Imports OK')" 2>/dev/null; then
        log_info "✅ Dépendances Python OK"
    else
        log_error "❌ Problème dépendances Python"
        return 1
    fi
    
    # Test configuration
    if sudo -u "$SERVICE_USER" "$PYTHON_VENV/bin/python" -c "import json; json.load(open('/opt/bender/audio_config.json')); print('Config OK')" 2>/dev/null; then
        log_info "✅ Configuration JSON valide"
    else
        log_error "❌ Configuration JSON invalide"
        return 1
    fi
}

show_status() {
    log_info "=== STATUT INSTALLATION ==="
    
    echo "📁 Répertoire: /opt/bender"
    echo "🐍 Python venv: $PYTHON_VENV"
    echo "👤 Utilisateur: $SERVICE_USER"
    echo "🔧 Service: bender-audio.service"
    echo ""
    echo "📋 Commandes utiles:"
    echo "  sudo systemctl start bender-audio    # Démarrer"
    echo "  sudo systemctl stop bender-audio     # Arrêter"
    echo "  sudo systemctl status bender-audio   # Statut"
    echo "  sudo journalctl -u bender-audio -f   # Logs temps réel"
    echo ""
    echo "🎯 Configuration: /opt/bender/audio_config.json"
    echo "📊 Logs: journalctl -u bender-audio"
}

# Fonction principale
main() {
    log_info "=== INSTALLATION BENDER AUDIO PIPELINE ==="
    log_info "Début: $(date)"
    
    check_root
    check_pi5
    
    install_system_deps
    setup_python_env
    setup_service_user
    install_pipeline_script
    create_systemd_service
    
    log_info "Tests de validation..."
    if test_audio_devices && test_pipeline; then
        log_info "✅ Installation réussie !"
        show_status
    else
        log_error "❌ Échec validation - vérifiez les logs"
        exit 1
    fi
    
    log_info "Fin: $(date)"
}

# Exécution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi