# Project Rules — Assistant Vocal « Bender »

## Référence
- Se conformer au document: **Dossier de définition — Assistant Vocal « Bender » (v1.2)** du repo.
- Toute décision doit citer la section du dossier concernée dans `DECISIONS.md`.

## Périmètre machines
- **Uniquement**: Dell **T630** (Windows Server 2022 + Docker/WSL2), **Raspberry Pi 5**, **ESP32**.
- **Home Assistant** avec **Mosquitto** (MQTTS + ACL).
- **Interdit**: toute autre machine (ex: Beelink), tout service cloud.

## Ordre des phases (obligatoire)
1) **Maquette & câblage** (Pi, ESP32, mics, amplis, quelques LEDs)
2) **Dev/Install** (Pi: pipeline audio+router+UI+systemd | ESP32: firmware | T630: Docker ASR/LLM/TTS + voix Piper par défaut)
3) **Tests maquette** (latences, WER, faux réveils/h, sync LEDs, AEC)
4) **Intégration mécanique** (par l’utilisateur)
5) **Paramétrages & tests finaux** (persona, mémoire, palettes, confirmations, TLS/ACL)
6) **Évolution v1.1**: **RVC** derrière Piper (entraîner à partir des samples), toggle UI

## Contraintes techniques incontournables
- **Pinouts RPi5 I²S**: BCLK=GPIO18/pin12, LRCLK=GPIO19/pin35, DIN(mics→Pi)=GPIO20/pin38, DOUT(Pi→amps)=GPIO21/pin40.  
  INMP441×2: bus partagé, SD commun vers GPIO20 ; L/R=GND (front/Left), L/R=3V3 (torse/Right).  
  MAX98357A×2: bus partagé, 1 ampli par HP 4 Ω, 5 V.
- **ESP32 → WS2812E**: GPIO16 (teeth,18), GPIO17 (eye_left,9), GPIO21 (eye_right,9) + R 330 Ω/data, condo 1000 µF, GND commun, alim 5 V/5 A, fusible 2.5–3 A.
- **Audio**: AEC WebRTC (PipeWire/PulseAudio, ref monitor), VAD webrtcvad, in 48 kHz → ASR 16 kHz, EQ/limiter.
- **ASR/LLM/TTS**: faster-whisper (Wyoming, streaming), Ollama (Mistral-7B-Instruct Q4 **ou** Qwen2.5-7B-Instruct Q4), Piper (Wyoming).
- **Voix par défaut (v1)**: voix FR Piper **officielle**, **version pinnée** + **SHA-256 vérifié** → `voice-id = fr-default@X.Y`.  
  Gestionnaire de voix UI: choix **Piper pur** (défaut) vs **Piper→RVC** (v1.1), sliders mix/pitch, checksums affichés.
- **MQTT** (TLS+ACL): topics = `bender/asr/partial|final`, `bender/intent`, `bender/tts/say`, `bender/led/state|viseme|env|config`, `bender/sys/metrics|log`.  
  Retained **uniquement** pour `…/config`/états non volatils.
- **Plan B audio out**: si full-duplex I²S bloque, conserver mics I²S, sortie via **DAC USB** + ampli.

## Gestion projet (obligatoire)
- Maintenir **en permanence**: `TODO.md` (priorisé, épics/tâches/dépendances/DoD), `DECISIONS.md`, `RISKS.md`, `METRICS.md`, `CHANGELOG.md`.
- Chaque phase = livrables de validation (tests, métriques, captures) + mini-démo.
- Secrets hors Git (`.env.local`), fournir `.env.sample`.
- Branches: `main` protégée, PR avec checklist (tests + docs + DoD).

## Définitions de Done (extraits)
- **v1**: domotique <1.5 s médiane ; conversation 2.5–3 s ; AEC stable ; LEDs sync <60 ms ; UI complète ; **voix par défaut** installée + **SHA-256 vérifié** ; TLS/ACL ok ; mémoire longue opérationnelle.  
- **v1.1**: **RVC** intégré derrière Piper; toggle UI; paramètres persistés; visèmes Piper conservés.
