#!/usr/bin/env python3
"""
Bender UI - Configuration
Paramètres de configuration pour l'interface utilisateur
"""

import os
from pathlib import Path

# Chemins de base
BASE_DIR = Path(__file__).parent
STATIC_DIR = BASE_DIR / "static"
VOICES_DIR = Path("/opt/bender/voices")
LOGS_DIR = Path("/var/log/bender")

# Configuration serveur
SERVER_CONFIG = {
    "host": "0.0.0.0",
    "port": 8080,
    "reload": False,  # True en développement seulement
    "workers": 1
}

# Configuration TLS (production)
TLS_CONFIG = {
    "enabled": False,  # À activer en production
    "cert_file": "/opt/bender/certs/bender-ui.crt",
    "key_file": "/opt/bender/certs/bender-ui.key"
}

# Configuration MQTT
MQTT_CONFIG = {
    "broker_host": os.getenv("MQTT_HOST", "192.168.1.138"),
    "broker_port": int(os.getenv("MQTT_PORT", "1883")),
    "username": os.getenv("MQTT_USER", "bender"),
    "password": os.getenv("MQTT_PASS", "bender123"),
    "tls_enabled": False,  # À activer avec Mosquitto TLS
    "topics": {
        "status": "bender/sys/metrics",
        "audio_status": "bender/audio/status",
        "tts_say": "bender/tts/say",
        "led_control": "bender/led/config"
    }
}

# Configuration Home Assistant
HA_CONFIG = {
    "base_url": os.getenv("HA_URL", "http://192.168.1.138:8123"),
    "token": os.getenv("HA_TOKEN", ""),
    "timeout": 10
}

# Configuration audio par défaut
AUDIO_CONFIG = {
    "input_device": "hw:0,0",  # I²S mics
    "output_device": "hw:0,1",  # I²S amplis
    "sample_rate": 48000,
    "channels": 2,
    "buffer_size": 1024,
    "aec_enabled": True,
    "vad_enabled": True,
    "vad_aggressiveness": 2
}

# Configuration voix Piper
VOICE_CONFIG = {
    "default_voice": "fr-siwis-medium",
    "voices_dir": VOICES_DIR,
    "download_url": "https://huggingface.co/rhasspy/piper-voices/resolve/main",
    "supported_voices": {
        "fr-siwis-medium": {
            "model_file": "fr_FR-siwis-medium.onnx",
            "config_file": "fr_FR-siwis-medium.onnx.json",
            "checksum": ""  # À remplir lors du téléchargement
        }
    }
}

# Configuration système
SYSTEM_CONFIG = {
    "services": [
        "bender-audio",
        "bender-intent",
        "bender-ui"
    ],
    "log_files": {
        "audio": LOGS_DIR / "audio.log",
        "intent": LOGS_DIR / "intent.log",
        "ui": LOGS_DIR / "ui.log"
    },
    "metrics_interval": 5,  # secondes
    "max_log_lines": 1000
}

# Configuration sécurité
SECURITY_CONFIG = {
    "allowed_origins": [
        "https://192.168.1.104:8080",
        "http://192.168.1.104:8080",
        "http://localhost:3000"  # React dev server
    ],
    "api_key_required": False,  # À activer en production
    "rate_limit": {
        "enabled": False,
        "requests_per_minute": 60
    }
}

# Fonction pour charger la config depuis .env
def load_env_config():
    """Charge la configuration depuis les variables d'environnement"""
    env_file = BASE_DIR.parent / ".env.local"
    if env_file.exists():
        with open(env_file) as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    key, value = line.strip().split('=', 1)
                    os.environ[key] = value

# Charger la config au démarrage
load_env_config()