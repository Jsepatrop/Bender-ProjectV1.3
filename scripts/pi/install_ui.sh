#!/bin/bash
# Installation de l'interface utilisateur Bender
# Usage: ./install_ui.sh

set -euo pipefail

# Configuration
UI_DIR="/opt/bender/ui"
CERTS_DIR="/opt/bender/certs"
SERVICE_FILE="/etc/systemd/system/bender-ui.service"
USER="bender"
GROUP="bender"

echo "=== Installation Interface Utilisateur Bender ==="

# Vérifier les privilèges
if [[ $EUID -ne 0 ]]; then
   echo "Erreur: Ce script doit être exécuté en tant que root (sudo)"
   exit 1
fi

# Créer les répertoires
echo "Création des répertoires..."
mkdir -p "$UI_DIR"
mkdir -p "$UI_DIR/static"
mkdir -p "$UI_DIR/templates"
mkdir -p "$CERTS_DIR"

# Copier les fichiers de l'UI
echo "Copie des fichiers de l'interface..."
cp bender_ui/app.py "$UI_DIR/"
cp bender_ui/config.py "$UI_DIR/"
cp bender_ui/requirements.txt "$UI_DIR/"
cp bender_ui/index.html "$UI_DIR/templates/"
cp bender_ui/static/app.js "$UI_DIR/static/"

# Créer le fichier .env.sample
echo "Création du fichier de configuration..."
cat > "$UI_DIR/.env.sample" << 'EOF'
# Configuration Bender UI
# Copier vers .env.local et adapter les valeurs

# Serveur
HOST=0.0.0.0
PORT=8080
DEBUG=false

# TLS
SSL_KEYFILE=/opt/bender/certs/server.key
SSL_CERTFILE=/opt/bender/certs/server.crt

# MQTT
MQTT_HOST=192.168.1.138
MQTT_PORT=8883
MQTT_USERNAME=bender
MQTT_PASSWORD=your_mqtt_password
MQTT_CA_CERT=/opt/bender/certs/ca.crt
MQTT_CERT_FILE=/opt/bender/certs/client.crt
MQTT_KEY_FILE=/opt/bender/certs/client.key

# Home Assistant
HA_URL=https://192.168.1.138:8123
HA_TOKEN=your_ha_token

# Audio
AUDIO_INPUT_DEVICE=hw:1,0
AUDIO_OUTPUT_DEVICE=hw:1,0
SAMPLE_RATE=48000
CHANNELS=2

# Voix Piper
PIPER_VOICES_DIR=/opt/bender/voices
DEFAULT_VOICE=fr_FR-siwis-medium

# Système
SYSTEM_SERVICES=audio_pipeline,intent_router,mqtt,home_assistant
LOG_LEVEL=INFO
EOF

# Installer les dépendances Python
echo "Installation des dépendances Python..."
pip3 install -r "$UI_DIR/requirements.txt"

# Générer les certificats TLS si nécessaire
if [[ ! -f "$CERTS_DIR/server.crt" ]]; then
    echo "Génération des certificats TLS..."
    
    # Créer la clé privée
    openssl genrsa -out "$CERTS_DIR/server.key" 2048
    
    # Créer le certificat auto-signé
    openssl req -new -x509 -key "$CERTS_DIR/server.key" -out "$CERTS_DIR/server.crt" -days 365 -subj "/C=FR/ST=France/L=Local/O=Bender/OU=UI/CN=bender.local"
    
    echo "Certificats TLS générés dans $CERTS_DIR"
else
    echo "Certificats TLS déjà présents"
fi

# Définir les permissions
echo "Configuration des permissions..."
chown -R "$USER:$GROUP" "$UI_DIR"
chown -R "$USER:$GROUP" "$CERTS_DIR"
chmod 755 "$UI_DIR"
chmod 644 "$UI_DIR"/*.py
chmod 644 "$UI_DIR"/*.txt
chmod 644 "$UI_DIR/templates"/*.html
chmod 644 "$UI_DIR/static"/*.js
chmod 600 "$CERTS_DIR"/*.key
chmod 644 "$CERTS_DIR"/*.crt

# Installer le service systemd
echo "Installation du service systemd..."
cp bender-ui.service "$SERVICE_FILE"
systemctl daemon-reload
systemctl enable bender-ui.service

# Créer le fichier de configuration local par défaut
if [[ ! -f "$UI_DIR/.env.local" ]]; then
    echo "Création du fichier de configuration local..."
    cp "$UI_DIR/.env.sample" "$UI_DIR/.env.local"
    chown "$USER:$GROUP" "$UI_DIR/.env.local"
    chmod 600 "$UI_DIR/.env.local"
    
    echo "ATTENTION: Éditez $UI_DIR/.env.local avec vos paramètres avant de démarrer le service"
fi

# Vérifier la syntaxe Python
echo "Vérification de la syntaxe..."
cd "$UI_DIR"
python3 -m py_compile app.py
python3 -m py_compile config.py

echo "=== Installation terminée ==="
echo ""
echo "Prochaines étapes:"
echo "1. Éditez $UI_DIR/.env.local avec vos paramètres"
echo "2. Démarrez le service: sudo systemctl start bender-ui.service"
echo "3. Vérifiez le statut: sudo systemctl status bender-ui.service"
echo "4. Accédez à l'interface: https://192.168.1.104:8080"
echo ""
echo "Logs du service: sudo journalctl -u bender-ui.service -f"