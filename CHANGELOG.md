# CHANGELOG - Assistant Vocal « Bender »

Tous les changements notables de ce projet seront documentés dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Non publié]

### Ajouté
- Structure projet initiale avec documentation complète
- TODO.md avec roadmap détaillée par EPICs
- DECISIONS.md pour traçabilité des choix techniques
- RISKS.md avec matrice des risques et mitigations
- METRICS.md définissant objectifs de performance
- Arborescence projet (/scripts, /services, /ui, /firmware, etc.)

### En cours
- Validation pré-requis (accès machines, matériel)
- Préparation scripts d'installation

---

## [1.2.0] - Planifié

### Objectifs v1.2 (Release finale)
- Pipeline audio complet et stable
- UI Web complète avec gestionnaire de voix
- Voix FR par défaut reproductible (SHA-256 vérifié)
- TLS/ACL sécurisés
- Métriques HA intégrées
- Mémoire longue fonctionnelle
- Documentation utilisateur complète

---

## [1.1.0] - Planifié (Évolution RVC)

### Ajouté
- Voice Conversion (RVC) après Piper
- Toggle UI : voix par défaut ↔ Piper→RVC
- Entraînement modèle RVC avec samples utilisateur
- Gestionnaire de profils voix (export/import)
- Sliders mix/pitch pour RVC

### Modifié
- Pipeline TTS : Texte → Piper → [RVC optionnel] → HP
- UI gestionnaire de voix étendue
- Visèmes conservés depuis Piper pré-RVC

---

## [1.0.0] - Planifié (Release v1)

### Ajouté
- Wake word "Bender" avec Porcupine/openWakeWord
- Pipeline audio I²S full-duplex (2×INMP441 + 2×MAX98357A)
- AEC WebRTC + VAD webrtcvad
- ASR faster-whisper (Wyoming, streaming)
- LLM Ollama (Mistral-7B-Instruct Q4 ou Qwen2.5-7B-Instruct Q4)
- TTS Piper (Wyoming) avec voix FR par défaut
- Router intents vers Home Assistant
- LEDs ESP32 (3 chaînes WS2812E, NeoPixelBus RMT)
- UI Web FastAPI + React (HTTPS)
- 7 services systemd Pi
- MQTT TLS + ACL strictes
- Métriques HA (latences, CPU/temp, WER, faux réveils)
- Mémoire longue SQLite + embeddings
- Persona Bender sarcastique FR

### Sécurité
- TLS activé par défaut (UI + MQTT)
- Certificats auto-signés gérés localement
- ACL Mosquitto par rôle (Pi/ESP32/T630)
- Logs audio avec quotas/rétention
- Aucune exposition Internet

---

## [0.3.0] - Planifié (Tests maquette)

### Ajouté
- Tests latences bout-en-bout
- Validation WER (silence/TV faible/forte)
- Mesure faux réveils/h
- Tests synchronisation LEDs (<60ms)
- Calibration AEC/VAD
- Métriques de performance automatisées

### Validé
- Latence domotique < 1.5s médiane
- Latence conversation 2.5-3s
- WER acceptable par condition
- LEDs sync conforme objectifs
- AEC stable sans larsen

---

## [0.2.0] - Planifié (Dev/Install)

### Ajouté
- Services Pi : wake, audio, router, TTS client, LEDs client, UI, métriques
- Firmware ESP32 : NeoPixelBus RMT + MQTT client
- Containers T630 : Ollama, Piper, faster-whisper
- Téléchargement voix Piper FR par défaut + vérification SHA-256
- Configuration MQTT TLS + ACL
- UI Web sections principales

### Technique
- Docker/WSL2 sur T630
- PipeWire/PulseAudio Pi avec AEC
- Systemd services avec dépendances
- MQTT topics selon spécification
- Certificats TLS auto-générés

---

## [0.1.0] - Planifié (Maquette & câblage)

### Ajouté
- Câblage I²S Pi5 (BCLK=GPIO18, LRCLK=GPIO19, DIN=GPIO20, DOUT=GPIO21)
- Installation 2×INMP441 (front L/R=GND, torse L/R=3V3)
- Installation 2×MAX98357A + HP 4Ω
- Câblage ESP32 → 3×WS2812E (GPIO16/17/21)
- Alimentation 5V/5A LEDs + protection
- Tests basiques capture/playback audio
- Tests LEDs couleurs de base

### Validé
- I²S full-duplex fonctionnel (ou Plan B DAC USB)
- Capture stéréo 48kHz opérationnelle
- Playback stéréo sans distorsion
- 36 LEDs WS2812E contrôlées
- Alimentation stable sous charge

---

## [0.0.1] - 2024-01-XX (Initialisation)

### Ajouté
- Dossier de définition v1.2 analysé
- Structure projet créée
- Documentation de gestion projet
- Arborescence complète
- Scripts squelettes préparés
- Pré-requis identifiés

### Documentation
- README.md avec vue d'ensemble
- TODO.md roadmap détaillée
- DECISIONS.md choix techniques
- RISKS.md matrice des risques
- METRICS.md objectifs performance
- PREREQUIS.md informations manquantes

---

## Conventions

### Types de changements
- **Ajouté** : nouvelles fonctionnalités
- **Modifié** : changements de fonctionnalités existantes
- **Déprécié** : fonctionnalités bientôt supprimées
- **Supprimé** : fonctionnalités supprimées
- **Corrigé** : corrections de bugs
- **Sécurité** : corrections de vulnérabilités

### Versioning
- **MAJOR** : changements incompatibles
- **MINOR** : nouvelles fonctionnalités compatibles
- **PATCH** : corrections compatibles

### Références
- Chaque changement référence la section du dossier de définition
- Liens vers issues/PRs quand applicable
- Métriques de validation incluses