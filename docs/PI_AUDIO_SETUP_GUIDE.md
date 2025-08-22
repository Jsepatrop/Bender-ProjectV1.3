# Guide de Configuration Audio - Raspberry Pi 5

## Vue d'ensemble

Ce guide détaille la configuration du pipeline audio pour l'Assistant Vocal Bender sur Raspberry Pi 5, incluant :
- Configuration I²S pour microphones INMP441 et amplificateurs MAX98357A
- Setup PipeWire avec AEC WebRTC
- Tests de validation audio

## Prérequis

### Matériel requis
- Raspberry Pi 5 avec Raspberry Pi OS
- 2× microphones INMP441 (câblés selon pinouts)
- 2× amplificateurs MAX98357A (câblés selon pinouts)
- Haut-parleurs 4Ω connectés aux amplificateurs

### Pinouts I²S (OBLIGATOIRES)
```
BCLK  = GPIO18 (pin 12)
LRCLK = GPIO19 (pin 35) 
DIN   = GPIO20 (pin 38) - Signal des microphones vers Pi
DOUT  = GPIO21 (pin 40) - Signal du Pi vers amplificateurs
```

### Câblage microphones INMP441
```
Microphone Front (L/R = GND) :
- VDD → 3.3V
- GND → GND
- SD → GPIO20 (partagé)
- WS → GPIO19 (partagé)
- SCK → GPIO18 (partagé)
- L/R → GND

Microphone Torse (L/R = 3V3) :
- VDD → 3.3V
- GND → GND
- SD → GPIO20 (partagé)
- WS → GPIO19 (partagé)
- SCK → GPIO18 (partagé)
- L/R → 3.3V
```

### Câblage amplificateurs MAX98357A
```
Amplificateur Gauche :
- VIN → 5V
- GND → GND
- DIN → GPIO21 (partagé)
- BCLK → GPIO18 (partagé)
- LRC → GPIO19 (partagé)
- GAIN → Non connecté (9dB par défaut)

Amplificateur Droit :
- VIN → 5V
- GND → GND
- DIN → GPIO21 (partagé)
- BCLK → GPIO18 (partagé)
- LRC → GPIO19 (partagé)
- GAIN → VIN (15dB)
```

## Installation

### 1. Préparation
```bash
# Cloner le projet Bender
cd ~/
git clone <repo_bender>
cd bender-project

# Copier la configuration
cp scripts/pi/.env.sample scripts/pi/.env.local

# Éditer la configuration si nécessaire
nano scripts/pi/.env.local
```

### 2. Exécution du script
```bash
# Rendre le script exécutable
chmod +x scripts/pi/setup_audio.sh

# Exécuter la configuration
./scripts/pi/setup_audio.sh
```

### 3. Redémarrage
```bash
# Redémarrer pour activer la configuration I²S
sudo reboot
```

## Validation

### Tests automatiques
Le script effectue automatiquement :
1. **Test de capture** : Enregistrement 5s avec analyse des niveaux
2. **Test de lecture** : Génération et lecture de tonalités stéréo

### Tests manuels post-installation

#### Vérifier les devices audio
```bash
# Lister les devices ALSA
aplay -l
arecord -l

# Vérifier PipeWire
pw-cli info
pw-cli ls Node
```

#### Test capture manuel
```bash
# Enregistrer 10 secondes
arecord -D bender_capture -f S32_LE -r 48000 -c 2 -d 10 test.wav

# Analyser le fichier
sox test.wav -n stat
```

#### Test lecture manuel
```bash
# Générer tonalité test
sox -n -r 48000 -c 2 -b 32 tone.wav synth 5 sine 440

# Lire le fichier
aplay -D bender_playback tone.wav
```

## Diagnostic

### Problèmes courants

#### Pas de device I²S détecté
```bash
# Vérifier la configuration boot
grep i2s /boot/firmware/config.txt

# Vérifier les modules kernel
lsmod | grep snd

# Redémarrer si nécessaire
sudo reboot
```

#### Pas de signal audio en capture
1. Vérifier le câblage des microphones
2. Vérifier l'alimentation 3.3V
3. Tester avec un multimètre les connexions GPIO
4. Vérifier les niveaux ALSA :
   ```bash
   alsamixer
   # Augmenter le gain de capture si disponible
   ```

#### Pas de son en lecture
1. Vérifier le câblage des amplificateurs
2. Vérifier l'alimentation 5V
3. Vérifier les haut-parleurs (résistance ~4Ω)
4. Tester avec un autre device :
   ```bash
   aplay -D hw:0,0 tone.wav
   ```

#### AEC ne fonctionne pas
1. Vérifier que PipeWire est actif :
   ```bash
   systemctl --user status pipewire
   ```
2. Vérifier la configuration AEC :
   ```bash
   pw-cli ls Node | grep -i echo
   ```
3. Redémarrer PipeWire :
   ```bash
   systemctl --user restart pipewire pipewire-pulse
   ```

### Logs de diagnostic
```bash
# Logs système
journalctl -u pipewire --user -f

# Logs ALSA
dmesg | grep -i audio
dmesg | grep -i i2s

# Debug PipeWire
PIPEWIRE_DEBUG=3 pipewire
```

## Configuration avancée

### Ajustement des paramètres AEC
Éditer `~/.config/pipewire/pipewire-pulse.conf.d/bender-aec.conf` :
```
aec.args = {
    analog_gain_control = false
    digital_gain_control = true
    noise_suppression = true      # Réduction de bruit
    voice_detection = true        # Détection vocale
    extended_filter = true        # Filtre étendu
    delay_agnostic = true         # Compensation délai
    high_pass_filter = true       # Filtre passe-haut
}
```

### Ajustement des latences
Éditer `~/.config/pipewire/pipewire.conf.d/bender-audio.conf` :
```
context.properties = {
    default.clock.quantum = 512   # Plus petit = moins de latence
    default.clock.min-quantum = 32
    default.clock.max-quantum = 2048
}
```

## Intégration avec le pipeline Bender

Une fois la configuration audio validée :
1. Les microphones sont disponibles via `bender_mic_aec`
2. Les haut-parleurs sont disponibles via `bender_speaker_aec`
3. L'AEC WebRTC est actif pour éviter l'écho
4. Le pipeline peut être intégré avec Wyoming/faster-whisper

## Plan B : DAC USB

En cas de problème avec l'I²S full-duplex :
1. Conserver les microphones en I²S (capture uniquement)
2. Utiliser un DAC USB pour la sortie audio
3. Modifier la configuration ALSA pour séparer capture/playback

Voir `DECISIONS.md` pour les détails du Plan B.