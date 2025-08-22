# Assistant Vocal « Bender » v1.2

## Vue d'ensemble

Assistant vocal local intégré dans une tête Bender (Ø 10 cm × H 20 cm) :
- Écoute (wake word + ASR FR robuste)
- Contrôle domotique Home Assistant
- Converse (persona Bender sarcastique FR)
- Parle en voix FR par défaut (Piper) → évolution RVC v1.1
- Réagit visuellement (yeux/dents WS2812E synchronisés)
- 100% local, TLS partout

## Architecture

- **Dell T630** (Windows Server 2022 + Docker/WSL2) : ASR, LLM, TTS
- **Raspberry Pi 5** : Orchestrateur, wake, AEC/VAD, router, UI Web
- **ESP32** : Contrôle LEDs (3 chaînes WS2812E indépendantes)
- **Home Assistant + Mosquitto** : Broker MQTT (TLS + ACL)

## Objectifs v1

- Domotique < 1,5 s médiane
- Conversation 2,5–3 s typiques
- AEC/VAD stable, faux réveils maîtrisés
- LEDs sync < 60 ms (RMS)
- Voix FR par défaut reproductible (version pinnée + SHA-256)
- UI complète HTTPS, TLS/ACL, mémoire longue

## Évolution v1.1

- Voice Conversion (RVC) : Piper → voix Bender-like
- Toggle UI pour basculer voix par défaut ↔ RVC
- Entraînement avec samples utilisateur (10-30 min)

## Structure projet

Voir `TODO.md` pour la roadmap détaillée et `docs/` pour la documentation technique.

## Sécurité

- Local-only, pas d'exposition Internet
- TLS activé (UI & MQTT), certs auto-signés
- ACL Mosquitto, comptes séparés
- Logs audio avec quotas/rétention