#!/bin/bash
# =============================================================================
# Setup Audio Pipeline - Raspberry Pi 5
# Assistant Vocal « Bender » v1.2
# =============================================================================

# Configuration audio I²S full-duplex avec AEC WebRTC et VAD
# Pinouts: BCLK=GPIO18/pin12, LRCLK=GPIO19/pin35, DIN=GPIO20/pin38, DOUT=GPIO21/pin40
# Référence : Dossier de définition section "Audio I²S full-duplex"

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")" 
LOG_FILE="/var/log/bender/audio_setup.log"

# Couleurs pour logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }

# =============================================================================
# FONCTIONS PRINCIPALES (SQUELETTES)
# =============================================================================

check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    # Vérifier Raspberry Pi 5
    if ! grep -q "Raspberry Pi 5" /proc/cpuinfo 2>/dev/null; then
        log_error "Ce script nécessite un Raspberry Pi 5"
        exit 1
    fi
    
    # Vérifier utilisateur non-root
    if [[ $EUID -eq 0 ]]; then
        log_error "Ne pas exécuter en tant que root. Utiliser sudo pour les commandes système uniquement."
        exit 1
    fi
    
    # Charger variables d'environnement
    if [[ -f "$PROJECT_ROOT/.env.local" ]]; then
        source "$PROJECT_ROOT/.env.local"
        log_info "Variables .env.local chargées"
    else
        log_warn "Fichier .env.local non trouvé, utilisation des valeurs par défaut"
    fi
    
    # Vérifier GPIO I²S disponibles (18, 19, 20, 21)
    for gpio in 18 19 20 21; do
        if [[ -d "/sys/class/gpio/gpio$gpio" ]]; then
            log_warn "GPIO$gpio déjà exporté, possible conflit"
        fi
    done
    
    log_info "Prérequis validés"
}

install_audio_packages() {
    log_info "Installation des paquets audio..."
    
    # Mise à jour système
    log_info "Mise à jour du système..."
    sudo apt update
    
    # Installation PipeWire (remplace PulseAudio sur Pi OS récent)
    log_info "Installation PipeWire et dépendances..."
    sudo apt install -y \
        pipewire \
        pipewire-pulse \
        pipewire-alsa \
        wireplumber \
        pipewire-audio-client-libraries
    
    # Outils audio essentiels
    log_info "Installation outils audio..."
    sudo apt install -y \
        alsa-utils \
        sox \
        pulseaudio-utils \
        pavucontrol \
        audacity
    
    # Dépendances AEC WebRTC
    log_info "Installation dépendances AEC..."
    sudo apt install -y \
        libwebrtc-audio-processing-dev \
        libspeexdsp-dev \
        libasound2-dev
    
    # Python pour VAD
    log_info "Installation dépendances Python VAD..."
    sudo apt install -y python3-pip python3-dev
    pip3 install --user webrtcvad numpy scipy
    
    log_info "Installation paquets terminée"
}

configure_i2s_overlay() {
    log_info "Configuration overlay I²S..."
    
    # Backup configuration boot
    log_info "Sauvegarde /boot/firmware/config.txt..."
    sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.backup.$(date +%Y%m%d_%H%M%S)
    
    # Vérifier si I²S déjà configuré
    if grep -q "dtparam=i2s=on" /boot/firmware/config.txt; then
        log_info "I²S déjà activé dans config.txt"
    else
        log_info "Activation I²S dans config.txt..."
        echo "# Bender Audio I²S Configuration" | sudo tee -a /boot/firmware/config.txt
        echo "dtparam=i2s=on" | sudo tee -a /boot/firmware/config.txt
    fi
    
    # Configuration ALSA pour I²S full-duplex
    log_info "Configuration ALSA I²S..."
    sudo tee /etc/asound.conf > /dev/null << 'EOF'
# Bender Audio Configuration - I²S Full-Duplex
# INMP441 mics (capture) + MAX98357A amps (playback)
# Pinouts: BCLK=GPIO18, LRCLK=GPIO19, DIN=GPIO20, DOUT=GPIO21

pcm.!default {
    type asym
    playback.pcm "bender_playback"
    capture.pcm "bender_capture"
}

ctl.!default {
    type hw
    card 0
}

# Capture (INMP441 mics)
pcm.bender_capture {
    type hw
    card 0
    device 0
    format S32_LE
    rate 48000
    channels 2
}

# Playback (MAX98357A amps)
pcm.bender_playback {
    type hw
    card 0
    device 0
    format S32_LE
    rate 48000
    channels 2
}

# Test devices
pcm.test_capture {
    type hw
    card 0
    device 0
    format S32_LE
    rate 48000
    channels 2
}

pcm.test_playback {
    type hw
    card 0
    device 0
    format S32_LE
    rate 48000
    channels 2
}
EOF
    
    log_info "Configuration I²S terminée"
}

setup_pipewire_config() {
    log_info "Configuration PipeWire..."
    
    # Créer dossiers configuration PipeWire
    mkdir -p ~/.config/pipewire/pipewire.conf.d
    mkdir -p ~/.config/pipewire/pipewire-pulse.conf.d
    
    # Configuration PipeWire principale
    log_info "Configuration PipeWire principale..."
    cat > ~/.config/pipewire/pipewire.conf.d/bender-audio.conf << 'EOF'
# Bender Audio Configuration
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 1024
    default.clock.min-quantum = 32
    default.clock.max-quantum = 2048
}

context.modules = [
    { name = libpipewire-module-rt
        args = {
            nice.level = -11
            rt.prio = 88
            rt.time.soft = 200000
            rt.time.hard = 200000
        }
        flags = [ ifexists nofail ]
    }
    { name = libpipewire-module-protocol-native }
    { name = libpipewire-module-client-node }
    { name = libpipewire-module-adapter }
    { name = libpipewire-module-link-factory }
]
EOF
    
    # Configuration AEC WebRTC
    log_info "Configuration AEC WebRTC..."
    cat > ~/.config/pipewire/pipewire-pulse.conf.d/bender-aec.conf << 'EOF'
# Bender AEC Configuration
context.modules = [
    { name = libpipewire-module-echo-cancel
        args = {
            # Sources et sinks
            capture.props = {
                node.name = "bender_mic_raw"
                media.class = "Audio/Source"
                audio.rate = 48000
                audio.channels = 2
            }
            playback.props = {
                node.name = "bender_speaker_monitor"
                media.class = "Audio/Sink"
                audio.rate = 48000
                audio.channels = 2
            }
            source.props = {
                node.name = "bender_mic_aec"
                node.description = "Bender Microphone (AEC)"
            }
            sink.props = {
                node.name = "bender_speaker_aec"
                node.description = "Bender Speaker (AEC)"
            }
            # Paramètres AEC WebRTC
            aec.method = "webrtc"
            aec.args = {
                analog_gain_control = false
                digital_gain_control = true
                experimental_agc = false
                noise_suppression = true
                voice_detection = true
                extended_filter = true
                delay_agnostic = true
                high_pass_filter = true
            }
        }
    }
]
EOF
    
    # Redémarrer PipeWire pour appliquer la configuration
    log_info "Redémarrage PipeWire..."
    systemctl --user restart pipewire pipewire-pulse wireplumber
    sleep 3
    
    log_info "Configuration PipeWire terminée"
}

test_audio_capture() {
    log_info "Test capture audio..."
    
    local test_file="/tmp/bender_test_capture.wav"
    
    # Test enregistrement 5 secondes
    log_info "Enregistrement test 5s (parlez maintenant)..."
    if arecord -D bender_capture -f S32_LE -r 48000 -c 2 -d 5 "$test_file" 2>/dev/null; then
        log_info "Enregistrement réussi: $test_file"
        
        # Analyse du fichier audio
        if command -v sox >/dev/null 2>&1; then
            log_info "Analyse du signal capturé..."
            local stats=$(sox "$test_file" -n stat 2>&1)
            local rms_level=$(echo "$stats" | grep "RMS lev dB" | awk '{print $4}')
            local max_level=$(echo "$stats" | grep "Max level" | awk '{print $3}')
            
            log_info "Niveaux audio - RMS: ${rms_level:-N/A} dB, Max: ${max_level:-N/A}"
            
            # Vérifier si le signal n'est pas trop faible
            if [[ "$max_level" != "0.000000" ]]; then
                log_info "✅ Signal audio détecté"
                return 0
            else
                log_error "❌ Aucun signal audio détecté"
                return 1
            fi
        else
            # Vérification basique de la taille du fichier
            local file_size=$(stat -c%s "$test_file" 2>/dev/null || echo "0")
            if [[ $file_size -gt 100000 ]]; then
                log_info "✅ Fichier audio généré (${file_size} bytes)"
                return 0
            else
                log_error "❌ Fichier audio trop petit ou vide"
                return 1
            fi
        fi
    else
        log_error "❌ Échec de l'enregistrement"
        return 1
    fi
}

test_audio_playback() {
    log_info "Test playback audio..."
    
    # Test avec speaker-test si disponible
    if command -v speaker-test >/dev/null 2>&1; then
        log_info "Test haut-parleurs avec speaker-test (5s)..."
        if timeout 5s speaker-test -D bender_playback -c 2 -r 48000 -f S32_LE -t sine >/dev/null 2>&1; then
            log_info "✅ Test speaker-test réussi"
        else
            log_warn "⚠️ speaker-test échoué, test alternatif..."
        fi
    fi
    
    # Test avec génération de tonalité sox
    if command -v sox >/dev/null 2>&1; then
        local test_tone="/tmp/bender_test_tone.wav"
        log_info "Génération tonalité test stéréo..."
        
        # Générer tonalité stéréo : 440Hz gauche, 880Hz droite
        if sox -n -r 48000 -c 2 -b 32 "$test_tone" synth 3 sine 440 sine 880 2>/dev/null; then
            log_info "Lecture tonalité test (3s)..."
            if aplay -D bender_playback "$test_tone" >/dev/null 2>&1; then
                log_info "✅ Test lecture stéréo réussi"
                rm -f "$test_tone"
                return 0
            else
                log_error "❌ Échec lecture avec aplay"
                rm -f "$test_tone"
                return 1
            fi
        else
            log_error "❌ Échec génération tonalité"
            return 1
        fi
    else
        # Test basique avec aplay
        log_info "Test lecture avec /dev/zero (bruit blanc 2s)..."
        if timeout 2s aplay -D bender_playback -f S32_LE -r 48000 -c 2 /dev/zero >/dev/null 2>&1; then
            log_info "✅ Test lecture basique réussi"
            return 0
        else
            log_error "❌ Échec test lecture basique"
            return 1
        fi
    fi
}

setup_aec_calibration() {
    log_info "Calibration AEC..."
    
    # TODO: Configuration référence monitor
    # pactl load-module module-echo-cancel \
    #   source_name=bender_mic_aec \
    #   sink_name=bender_speaker_aec \
    #   aec_method=webrtc \
    #   aec_args='analog_gain_control=0 digital_gain_control=1'
    
    # TODO: Test suppression écho
    # Mesure signal ref vs signal capturé
    
    # TODO: Ajustement paramètres selon environnement
    
    log_warn "SQUELETTE: Calibration AEC non implémentée"
}

setup_vad_config() {
    log_info "Configuration VAD..."
    
    # TODO: Installation webrtcvad Python
    # pip3 install webrtcvad
    
    # TODO: Configuration aggressiveness=2 (défaut)
    # TODO: Configuration frame_duration=30ms
    
    # TODO: Test détection voix vs bruit
    
    log_warn "SQUELETTE: Configuration VAD non implémentée"
}

validate_audio_pipeline() {
    log_info "Validation pipeline audio complet..."
    
    # TODO: Test bout-en-bout
    # Micro → AEC → VAD → ASR (mock)
    
    # TODO: Mesure latences
    # Signal test → détection < 100ms
    
    # TODO: Validation qualité
    # SNR > 20dB, pas de distorsion
    
    # TODO: Test Plan B (DAC USB si I²S échoue)
    
    log_warn "SQUELETTE: Validation pipeline non implémentée"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    log_info "=== SETUP AUDIO PIPELINE - RASPBERRY PI 5 ==="
    log_info "Référence: Dossier de définition v1.2, section Audio"
    log_info "Pinouts: BCLK=GPIO18, LRCLK=GPIO19, DIN=GPIO20, DOUT=GPIO21"
    
    # Vérifications préliminaires
    log_info "Phase 1: Vérifications préliminaires"
    if ! check_prerequisites; then
        log_error "❌ Échec des vérifications préliminaires"
        exit 1
    fi
    
    # Installation des paquets
    log_info "Phase 2: Installation des paquets audio"
    if ! install_audio_packages; then
        log_error "❌ Échec de l'installation des paquets"
        exit 1
    fi
    
    # Configuration I²S
    log_info "Phase 3: Configuration I²S"
    if ! configure_i2s_overlay; then
        log_error "❌ Échec de la configuration I²S"
        exit 1
    fi
    
    # Configuration PipeWire
    log_info "Phase 4: Configuration PipeWire + AEC"
    if ! setup_pipewire_config; then
        log_error "❌ Échec de la configuration PipeWire"
        exit 1
    fi
    
    # Attendre que les services se stabilisent
    log_info "Attente stabilisation des services audio..."
    sleep 5
    
    # Calibration (squelettes)
    setup_aec_calibration
    setup_vad_config
    
    # Tests audio
    log_info "Phase 5: Tests audio"
    local capture_ok=false
    local playback_ok=false
    
    if test_audio_capture; then
        capture_ok=true
    fi
    
    if test_audio_playback; then
        playback_ok=true
    fi
    
    # Validation pipeline (squelette)
    validate_audio_pipeline
    
    # Rapport final
    log_info "=== RAPPORT DE CONFIGURATION ==="
    log_info "Capture audio: $([ "$capture_ok" = true ] && echo "✅ OK" || echo "❌ ÉCHEC")"
    log_info "Lecture audio: $([ "$playback_ok" = true ] && echo "✅ OK" || echo "❌ ÉCHEC")"
    
    if [ "$capture_ok" = true ] && [ "$playback_ok" = true ]; then
        log_info "🎉 Configuration audio terminée avec succès!"
        log_info "Redémarrage recommandé pour finaliser la configuration I²S"
        log_info "Commande: sudo reboot"
        return 0
    else
        log_error "⚠️ Configuration partiellement réussie"
        log_info "Consultez les logs ci-dessus pour diagnostiquer les problèmes"
        log_warn "ATTENTION: Certaines fonctions sont encore des SQUELETTES"
        return 1
    fi
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Vérification exécution en tant que root si nécessaire
    if [[ $EUID -eq 0 ]]; then
        log_error "Ne pas exécuter en tant que root"
        log_error "Utiliser sudo uniquement pour les commandes système"
        exit 1
    fi
    
    # Création dossier logs
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo chown "$USER:$USER" "$(dirname "$LOG_FILE")"
    
    # Exécution
    main "$@"
fi

# =============================================================================
# NOTES DE DÉVELOPPEMENT
# =============================================================================

# Ce script sera complété avec :
# 1. Chargement variables .env.local
# 2. Gestion erreurs robuste
# 3. Tests unitaires pour chaque fonction
# 4. Rollback automatique en cas d'échec
# 5. Métriques de validation (latence, qualité)
# 6. Documentation des paramètres optimaux
# 7. Support Plan B (DAC USB)
# 8. Intégration avec systemd services
#
# Références techniques :
# - PipeWire: https://pipewire.org/
# - WebRTC AEC: https://webrtc.org/
# - ALSA I²S: https://www.kernel.org/doc/html/latest/sound/
# - RPi GPIO: https://pinout.xyz/