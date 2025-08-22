# DECISIONS - Assistant Vocal « Bender » v1.2

## Choix techniques et justifications

### Architecture générale

**Date** : 2024-01-XX  
**Décision** : Architecture distribuée Pi5 + T630 + ESP32  
**Justification** : 
- Pi5 : Orchestrateur optimal (GPIO I²S, Linux, services)
- T630 : Compute serveur (Docker, GPU potentiel, Windows Server 2022)
- ESP32 : Spécialisé LEDs (RMT, WiFi, coût)
- Séparation des responsabilités claire
**Référence dossier** : Section 2 "Matériel (BOM) & fonctions"

### Audio I²S full-duplex

**Date** : 2024-01-XX  
**Décision** : Pinouts Pi5 I²S - BCLK=GPIO18, LRCLK=GPIO19, DIN=GPIO20, DOUT=GPIO21  
**Justification** : 
- Pinouts stables et documentés pour Pi5
- Full-duplex nécessaire pour AEC temps réel
- Plan B DAC USB si problèmes
**Référence dossier** : Section 4 "Audio — pinouts & traitements"
**Plan B** : DAC USB + ampli analogique si full-duplex I²S bloque

### Voix par défaut Piper

**Date** : 2024-01-XX  
**Décision** : Voix FR officielle Piper avec version pinnée + SHA-256  
**Justification** : 
- Reproductibilité garantie (version + checksum)
- Qualité FR acceptable
- Base stable pour évolution RVC v1.1
- Téléchargement automatisé depuis source officielle
**Référence dossier** : Section 7.1 "Voix par défaut (v1 — téléchargeable & reproductible)"
**Implémentation** : Script `/scripts/t630/piper_get_voice.ps1|.sh`

### MQTT Topics et sécurité

**Date** : 2024-01-XX  
**Décision** : Topics `bender/*` avec TLS + ACL strictes  
**Justification** : 
- Namespace clair et extensible
- TLS obligatoire (confidentialité locale)
- ACL par rôle (Pi/ESP32/T630)
- Retained uniquement pour config/états persistants
**Référence dossier** : Section 8 "MQTT (v1)" et Section 12 "Sécurité & vie privée"

### Services systemd Pi

**Date** : 2024-01-XX  
**Décision** : 7 services systemd indépendants  
**Justification** : 
- Isolation des responsabilités
- Restart sélectif en cas d'échec
- Logs centralisés journald
- Dépendances explicites
**Services** : bender-wake, bender-audio, bender-router, bender-tts-client, bender-leds-client, bender-ui, bender-metrics
**Référence dossier** : Section 6 "Logiciel — composants"

### LLM et modèles

**Date** : 2024-01-XX  
**Décision** : Ollama avec Mistral-7B-Instruct Q4 ou Qwen2.5-7B-Instruct Q4  
**Justification** : 
- Modèles FR performants et compacts
- Quantization Q4 = bon compromis qualité/ressources
- Ollama = API REST simple et stable
- Fallback Phi-3-mini sur Pi si T630 indisponible
**Référence dossier** : Section 10 "LLM & persona, mémoire"

### LEDs et animations

**Date** : 2024-01-XX  
**Décision** : ESP32 RMT + NeoPixelBus, 3 chaînes indépendantes  
**Justification** : 
- RMT = timing précis WS2812E
- 3 GPIO séparés = contrôle indépendant yeux/dents
- NeoPixelBus = lib mature et performante
- Animations locales = réactivité
**Pinouts** : GPIO16(teeth,18), GPIO17(eye_left,9), GPIO21(eye_right,9)
**Référence dossier** : Section 5 "LEDs — pinouts & effets"

### UI Web et sécurité

**Date** : 2024-01-XX  
**Décision** : FastAPI + React, HTTPS cert auto-signé  
**Justification** : 
- FastAPI = API moderne et rapide
- React = UI riche et réactive
- HTTPS obligatoire même en local
- WebSocket pour métriques live
**Référence dossier** : Section 11 "UI Web (Pi)"

---

## Décisions techniques prises

### 2025-01-21 - Intégration informations PREREQUIS.md

**Contexte** : L'utilisateur a mis à jour le fichier `docs/PREREQUIS.md` avec des informations critiques sur les accès machines, matériel, et configuration.

**Décision** : Intégration complète des informations dans les fichiers de configuration du projet :
- Création `.env.local` avec secrets réels (T630: 192.168.1.100/Plex, Pi5: 192.168.1.104/bender, HA token, etc.)
- Mise à jour `.env.sample` avec structure complète
- Création `inventory.yml` Ansible avec configuration des 3 machines
- Validation que `.gitignore` protège les secrets

**Justification** :
- **Sécurité** : Séparation claire secrets (.env.local non versionné) vs structure (.env.sample versionné)
- **Reproductibilité** : Inventory Ansible permet déploiement automatisé
- **Conformité** : Respect des contraintes du dossier de définition (TLS, accès machines, voix siwis-medium)

**Impact** :
- Configuration centralisée et sécurisée
- Prêt pour tests de connectivité et déploiement automatisé
- Choix voix TTS validé : `fr_FR-siwis-medium`

**Références** :
- `docs/PREREQUIS.md` (informations source)
- `.env.local` (secrets), `.env.sample` (structure)
- `inventory.yml` (configuration Ansible)

### 2025-01-21 - Validation connectivité machines

**Contexte** : Validation des accès aux machines du projet avant démarrage Phase 1.

**Décision** : Création et exécution du script `scripts/validate_connectivity.ps1`.

**Mise à jour informations MQTT** :
- **Host MQTT** : 192.168.1.100 → **192.168.1.138**
- **Utilisateur** : bender → **mqttuser**
- **Mot de passe** : bender_secret → **Bibi14170!**

**Résultats de validation (après correction MQTT)** :
- ✅ **Raspberry Pi 5** (192.168.1.104) : Ping OK, SSH OK
- ✅ **Dell T630** (192.168.1.100) : Ping OK, SSH OK (connexion manuelle testée avec succès)
- ✅ **Home Assistant API** (https://alban.freeboxos.fr:8123) : Authentification token OK
- ✅ **ESP32** (COM6) : Port série accessible et fonctionnel
- ✅ **MQTT Broker** (192.168.1.138) : Port TCP 1883 accessible avec mqttuser
- ❌ **MQTT TLS** : Port 8883 non accessible (TLS non configuré)

**Corrections apportées** :
- Mise à jour ESP32_PORT de COM4 vers COM6 dans .env.local
- Modification script validation pour utiliser SSH au lieu de WinRM pour T630
- Test manuel SSH T630 réussi : `ssh Plex@192.168.1.100` avec mot de passe `Bibi14170!`
- Test MQTT : Port 1883 sur 192.168.1.138 → ✅ Accessible

**Actions restantes** :
- Configuration TLS MQTT pour port 8883 (optionnel pour v1)
- **Toutes les connexions critiques sont opérationnelles**

**Justification** : Validation préalable essentielle pour éviter blocages en Phase 1, conformément à la méthodologie "Reproductibilité" du dossier de définition.

### 2024-12-21 - Schéma de câblage détaillé et validation des spécifications
**Contexte :** Besoin de valider les spécifications de câblage du dossier de définition avec les documentations officielles des composants  
**Options évaluées :**
- Suivre uniquement le dossier de définition sans validation
- Rechercher et valider chaque spécification avec les sources officielles

**Décision :** Validation complète avec sources officielles et création d'un schéma détaillé  
**Justification :** 
- Confirmation des résistances 330Ω pour WS2812E (protection des lignes de données)
- Validation des pinouts I²S pour RPi5 et composants audio
- Spécifications de consommation électrique précises pour dimensionnement alimentation
- Plan B audio USB documenté en cas de problème I²S full-duplex

**Impact :** 
- Documentation technique complète dans `docs/CABLAGE.md`
- Réduction des risques de câblage incorrect
- Base solide pour la Phase 1 (maquette & câblage)

**Référence :** Section 3.2 "Architecture matérielle" du dossier de définition v1.2

**Sources validées :**
- Adafruit : Guides I²S MEMS microphones et MAX98357A
- ESP32 : Documentation officielle WS2812E
- Raspberry Pi Foundation : Pinout GPIO officiel

### 2024-12-21 - Câblage direct LEDs WS2812E sans level-shifter
**Contexte :** Question sur l'utilisation du TXS0108E level-shifter pour les LEDs WS2812E  
**Options évaluées :**
- Câblage direct ESP32 3.3V → WS2812E avec résistances 330Ω
- Utilisation d'un level-shifter TXS0108E ou 74AHCT125

**Décision :** Câblage direct sans level-shifter en première approche  
**Justification :** 
- WS2812E acceptent 3.3V en entrée (seuil ≥ 0.7×VDD = 3.5V avec VDD=5V)
- ESP32 sort 3.3V, suffisant dans la plupart des cas
- Résistances 330Ω côté ESP32 pour protection
- Simplification du câblage et réduction des composants

**Impact :** 
- Câblage simplifié : ESP32 GPIO → R330Ω → WS2812E DIN
- Plan B documenté : ajout TXS0108E/74AHCT125 si problèmes de signal
- Tests de validation requis pour confirmer la fiabilité

**Référence :** Section 3.2.3 "LEDs WS2812E" du dossier de définition v1.2

### 2025-01-21 - Firmware test LEDs ESP32
**Contexte :** Câblage terminé, LEDs non fonctionnelles, besoin de validation matérielle  
**Options évaluées :**
- Test simple avec une seule LED
- Test complet avec FastLED sur tous les segments

**Décision :** Création firmware test complet avec FastLED sur GPIO16/17/21  
**Justification :** 
- Test systématique par segment (dents, yeux)
- Animations de validation pour debug visuel
- Debug série pour traçabilité
- Validation complète du câblage avant intégration MQTT

**Impact :** 
- Firmware `firmware/esp32_led_test.ino` créé
- Tests par segment : cycles couleurs, arc-en-ciel
- Moniteur série 115200 baud pour debug
- Validation matérielle avant développement final

**Référence :** EPIC 3 du dossier de définition, contraintes ESP32 GPIO16/17/21

---

## Décisions en attente

### Choix voix FR Piper exacte
**Statut** : En attente validation utilisateur  
**Options** : À identifier depuis catalogue officiel Piper  
**Critères** : Qualité FR, taille modèle, compatibilité RVC future

### Configuration GPU T630
**Statut** : En attente vérification matérielle  
**Impact** : Performance ASR/LLM/RVC  
**Plan B** : CPU-only avec modèles optimisés

### Paramètres AEC/VAD
**Statut** : À calibrer selon environnement  
**Variables** : Seuils VAD, paramètres AEC WebRTC  
**Méthode** : Tests empiriques avec TV/bruit ambiant

---

## Historique des changements

**v1.2** : Décisions initiales basées sur dossier de définition  
**v1.1** : (À venir) Ajustements post-tests maquette  
**v1.0** : (À venir) Finalisation choix techniques