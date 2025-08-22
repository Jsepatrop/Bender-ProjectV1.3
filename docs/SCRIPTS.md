# Scripts d'Installation et de Déploiement

## Vue d'ensemble

Ce document décrit les scripts d'installation et de déploiement du projet Assistant Vocal « Bender » v1.2.

**⚠️ IMPORTANT**: Tous les scripts actuels sont des **SQUELETTES NON FONCTIONNELS**. Ils seront complétés et testés lors des phases de développement correspondantes.

## Organisation des Scripts

```
scripts/
├── pi/                    # Scripts pour Raspberry Pi 5
│   └── setup_audio.sh     # Configuration pipeline audio I²S + AEC/VAD
├── t630/                  # Scripts pour Dell T630
│   ├── docker_bootstrap.ps1   # Bootstrap Docker + WSL2
│   └── piper_get_voice.ps1    # Téléchargement voix Piper FR par défaut
└── mqtt/                  # Scripts MQTT
    └── mosquitto_tls_and_acl.sh  # Configuration TLS + ACL
```

## Scripts par Machine

### Raspberry Pi 5 (`/scripts/pi/`)

#### `setup_audio.sh`
- **Phase**: 2 (Dev/Install Pi)
- **Objectif**: Configuration complète pipeline audio
- **Fonctionnalités**:
  - Configuration overlay I²S (pinouts: BCLK=GPIO18, LRCLK=GPIO19, DIN=GPIO20, DOUT=GPIO21)
  - Installation PipeWire/PulseAudio
  - Configuration AEC WebRTC avec référence monitor
  - Configuration VAD (webrtcvad)
  - Calibration niveaux audio (48kHz → 16kHz ASR)
  - Tests validation pipeline
- **Prérequis**: Raspberry Pi OS, accès sudo, matériel audio connecté
- **Usage futur**: `sudo ./setup_audio.sh`

### Dell T630 (`/scripts/t630/`)

#### `docker_bootstrap.ps1`
- **Phase**: 2 (Dev/Install T630)
- **Objectif**: Bootstrap environnement Docker + services IA
- **Fonctionnalités**:
  - Installation/configuration WSL2
  - Installation Docker Desktop
  - Configuration Docker Compose
  - Téléchargement images (Ollama, Wyoming Piper, faster-whisper)
  - Configuration firewall Windows
  - Tests connectivité services
- **Prérequis**: Windows Server 2022, droits administrateur
- **Usage futur**: `PowerShell -ExecutionPolicy Bypass -File docker_bootstrap.ps1`

#### `piper_get_voice.ps1`
- **Phase**: 2 (Dev/Install T630)
- **Objectif**: Téléchargement et validation voix Piper FR par défaut
- **Fonctionnalités**:
  - Téléchargement voix officielle Piper FR
  - Vérification SHA-256 (sécurité)
  - Installation dans répertoire Wyoming
  - Enregistrement voice-id (ex: `fr-default@1.2.0`)
  - Tests synthèse vocale
- **Prérequis**: Docker opérationnel, accès internet
- **Usage futur**: `PowerShell -ExecutionPolicy Bypass -File piper_get_voice.ps1`

### MQTT (`/scripts/mqtt/`)

#### `mosquitto_tls_and_acl.sh`
- **Phase**: 5 (Paramétrages finaux)
- **Objectif**: Configuration sécurité MQTT complète
- **Fonctionnalités**:
  - Génération CA locale + certificats TLS
  - Configuration Mosquitto (port 8883 TLS, 9001 WebSocket)
  - Création utilisateurs techniques avec mots de passe sécurisés
  - Configuration ACL stricte par rôle
  - Tests sécurité (connexions anonymes bloquées)
  - Validation topics Bender
- **Prérequis**: Mosquitto installé, OpenSSL, accès root
- **Usage futur**: `sudo ./mosquitto_tls_and_acl.sh`

## Ordre d'Exécution

Selon les phases du projet :

### Phase 2 - Dev/Install
1. **T630**: `docker_bootstrap.ps1` → `piper_get_voice.ps1`
2. **Pi5**: `setup_audio.sh`
3. **ESP32**: Firmware via PlatformIO (pas de script shell)

### Phase 5 - Paramétrages finaux
4. **MQTT**: `mosquitto_tls_and_acl.sh`

## Variables d'Environnement

Tous les scripts utilisent le fichier `.env.local` (à créer depuis `.env.sample`) :

```bash
# Exemple de variables utilisées
MQTT_BROKER_HOST=192.168.1.100
T630_HOST=192.168.1.200
PI5_HOST=192.168.1.150
PIPER_VOICE_VERSION=1.2.0
PIPER_VOICE_SHA256=abc123...
```

## Sécurité

### Bonnes Pratiques
- ✅ Tous les mots de passe générés automatiquement (32 caractères)
- ✅ Certificats TLS avec CA locale
- ✅ ACL MQTT strictes par rôle
- ✅ Vérification SHA-256 des téléchargements
- ✅ Logs détaillés avec rotation
- ✅ Sauvegarde configurations existantes

### Secrets
- ❌ **Jamais de secrets en dur dans les scripts**
- ✅ Utilisation `.env.local` (non versionné)
- ✅ Génération automatique mots de passe
- ✅ Permissions fichiers restrictives (600/640)

## Tests et Validation

Chaque script inclut :
- **Tests prérequis** : vérification environnement
- **Tests fonctionnels** : validation services
- **Tests sécurité** : vérification ACL/TLS
- **Métriques** : latences, performances
- **Rollback** : restauration en cas d'échec

## Logs et Monitoring

### Emplacements
- **Pi5**: `/var/log/bender/`
- **T630**: `C:\ProgramData\Bender\logs\`
- **MQTT**: `/var/log/mosquitto/`

### Niveaux
- `INFO` : Étapes principales
- `WARN` : Avertissements non bloquants
- `ERROR` : Erreurs bloquantes
- `DEBUG` : Détails techniques

## Développement

### Complétion des Scripts

Pour chaque script squelette :

1. **Analyser** les `TODO:` dans le code
2. **Implémenter** les fonctions marquées comme squelettes
3. **Tester** sur environnement de développement
4. **Valider** critères de Done (voir `TODO.md`)
5. **Documenter** dans `DECISIONS.md`

### Conventions

- **Bash** : `set -euo pipefail` (arrêt sur erreur)
- **PowerShell** : `$ErrorActionPreference = 'Stop'`
- **Logs** : Format uniforme avec timestamp
- **Retours** : Code 0 = succès, >0 = erreur
- **Idempotence** : Réexécution sans effet de bord

## Support

### Dépannage

1. **Vérifier logs** dans `/var/log/bender/` ou `C:\ProgramData\Bender\logs\`
2. **Contrôler prérequis** (versions, permissions, réseau)
3. **Tester manuellement** les étapes échouées
4. **Consulter** `DECISIONS.md` et `RISKS.md`

### Références

- **Dossier de définition** : Spécifications techniques
- **TODO.md** : Critères de Done par tâche
- **RISKS.md** : Plans B et mitigation
- **METRICS.md** : Seuils de performance

---

**Note** : Cette documentation sera mise à jour au fur et à mesure de l'implémentation des scripts lors des phases de développement.