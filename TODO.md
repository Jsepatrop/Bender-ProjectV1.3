# TODO - Assistant Vocal « Bender » v1.2

## Vue globale par EPICS

### EPIC 1 - Maquette & câblage
**Objectif** : Assembler Pi5, ESP32, 2×INMP441, 2×MAX98357A, quelques LEDs WS2812E selon pinouts définis
**Statut** : 🟡 En cours (câblage terminé, test LEDs en cours)
**Dépendances** : Matériel disponible, accès Pi5
**Accès Pi5** : SSH bender@192.168.1.104 (Pi OS Lite 64-bit installé)

### EPIC 2 - Dev/Install Pi
**Objectif** : Pipeline audio (AEC WebRTC, VAD), router intents HA, UI FastAPI+React HTTPS, services systemd
**Statut** : 🔴 Pending
**Dépendances** : E1 terminé, accès SSH Pi5

### EPIC 3 - Dev/Install ESP32
**Objectif** : Firmware NeoPixelBus RMT (GPIO16/17/21), MQTT client, animations locales
**Statut** : 🔴 Pending
**Dépendances** : E1 terminé, toolchain ESP32

### EPIC 4 - Dev/Install T630
**Objectif** : Docker WSL2, Ollama, Piper Wyoming, faster-whisper, téléchargement voix FR par défaut + SHA-256
**Statut** : 🔴 Pending
**Dépendances** : Accès WinRM T630, Docker installé

### EPIC 5 - Tests maquette
**Objectif** : Validation latences (<1.5s domotique, 2.5-3s conversation), WER, faux réveils/h, sync LEDs <60ms
**Statut** : 🔴 Pending
**Dépendances** : E2, E3, E4 terminés

### EPIC 6 - Intégration mécanique
**Objectif** : Montage final dans boîtier PETG (par utilisateur)
**Statut** : 🔴 Pending
**Dépendances** : E5 validé

### EPIC 7 - Paramétrages finaux
**Objectif** : Persona Bender, mémoire longue, palettes LEDs, confirmations HA, TLS/ACL
**Statut** : 🔴 Pending
**Dépendances** : E6 terminé

### EPIC 8 - Évolution v1.1 RVC
**Objectif** : Voice Conversion Piper→RVC, entraînement avec samples utilisateur, toggle UI
**Statut** : 🔴 Pending
**Dépendances** : v1 livrée et validée

---

## Tâches détaillées

### 🔥 EPIC 1 - Maquette & câblage

#### T1.1 - Câblage I²S Pi5 ✅ FAIT
**ID** : T1.1  
**Titre** : Configuration pinouts I²S full-duplex Pi5  
**Description** : Câbler selon pinouts définis : BCLK=GPIO18/pin12, LRCLK=GPIO19/pin35, DIN=GPIO20/pin38, DOUT=GPIO21/pin40  
**Dépendances** : Matériel disponible  
**Scripts envisagés** : `/scripts/pi/setup_audio.sh` (overlay I²S, PipeWire config)  
**Critères Done** : 
- [x] Overlay I²S activé dans /boot/config.txt
- [x] Pins correctement câblés et testés avec multimètre
- [x] PipeWire détecte les devices I²S
- [x] Documentation schéma de câblage (CABLAGE.md créé)
**Risques/Plan B** : Si full-duplex bloque → Plan B DAC USB pour sortie audio

#### T1.2 - Câblage INMP441×2 ✅ FAIT
**ID** : T1.2  
**Titre** : Installation microphones I²S stéréo  
**Description** : Bus partagé BCLK/LRCLK, SD commun→GPIO20, front L/R=GND, torse L/R=3V3  
**Dépendances** : T1.1 terminé  
**Scripts envisagés** : Test capture avec `arecord -D hw:1,0 -f S32_LE -r 48000 -c 2`  
**Critères Done** : 
- [x] 2 mics câblés selon schéma (résistances 330Ω, voir CABLAGE.md)
- [x] Capture stéréo fonctionnelle 48kHz
- [x] Niveaux différenciés front/torse vérifiés
**Risques/Plan B** : Problème bus → isoler 1 mic pour debug

#### T1.3 - Câblage MAX98357A×2
**ID** : T1.3  
**Titre** : Installation amplificateurs I²S  
**Description** : Bus partagé BCLK/LRCLK/DOUT, DIN commun→GPIO21, 1 ampli par HP 4Ω, alim 5V  
**Dépendances** : T1.1 terminé  
**Scripts envisagés** : Test playback avec `speaker-test -D hw:1,0 -c 2`  
**Critères Done** : 
- 2 amplis câblés selon schéma (CABLAGE.md), HP 4Ω connectés
- Playback stéréo fonctionnel
- Pas de distorsion à volume moyen
- Consommation mesurée <1.3A total
**Risques/Plan B** : Problème full-duplex → DAC USB + ampli analogique

#### T1.4 - Test LEDs ESP32 🟡 EN COURS
**ID** : T1.4  
**Titre** : Installation et test chaînes WS2812E  
**Description** : GPIO16(teeth,18), GPIO17(eye_left,9), GPIO21(eye_right,9), R 330Ω, condo 1000µF, alim 5V/5A  
**Dépendances** : ESP32 disponible  
**Scripts envisagés** : Test basique NeoPixelBus  
**Critères Done** : 
- [x] 3 chaînes LEDs câblées selon schéma (CABLAGE.md)
- [x] Résistances 330Ω installées sur chaque ligne de données
- [x] Alimentation 5V/5A + condo 1000µF + fusible 2.5-3A
- [ ] Test couleurs de base fonctionnel
- [ ] Consommation mesurée <2.2A à pleine luminosité
**Risques/Plan B** : Level-shifter 74AHCT125 si signaux instables

### 🔥 EPIC 2 - Dev/Install Pi

#### T2.1 - Setup audio Pi (AEC/VAD)
**ID** : T2.1  
**Titre** : Configuration pipeline audio avec AEC WebRTC  
**Description** : PipeWire/PulseAudio, AEC WebRTC (ref=monitor), VAD webrtcvad, EQ 2-4kHz  
**Dépendances** : T1.1, T1.2, T1.3 terminés  
**Scripts envisagés** : `/scripts/pi/setup_audio.sh`  
**Critères Done** : 
- AEC WebRTC configuré et stable (pas de larsen)
- VAD webrtcvad fonctionnel (seuils ajustables)
- Pipeline 48kHz→16kHz pour ASR
- EQ et limiter soft-clip opérationnels
**Risques/Plan B** : AEC instable → ajuster paramètres ou fallback sans AEC

#### T2.2 - Wake word detection
**ID** : T2.2  
**Titre** : Implémentation détection "Bender"  
**Description** : Porcupine ou openWakeWord, sensibilité réglable UI, timeout configurable  
**Dépendances** : T2.1 terminé  
**Scripts envisagés** : Service systemd `bender-wake`  
**Critères Done** : 
- Wake "Bender" détecté avec taux acceptable
- Sensibilité réglable via UI
- Faux réveils < seuil défini (à mesurer)
- Timeout post-wake configurable
**Risques/Plan B** : Modèle custom si Porcupine/openWakeWord insuffisant

#### T2.3 - Router intents HA
**ID** : T2.3  
**Titre** : Développement router NLU vers Home Assistant  
**Description** : Règles/slots/synonymes, couleurs HSV, comparatifs, import entités HA via API  
**Dépendances** : Accès API Home Assistant  
**Scripts envisagés** : Service systemd `bender-router`  
**Critères Done** : 
- Parsing intents domotique (lumières, prises, scènes, capteurs)
- Synonymes et alias configurables
- Gestion couleurs HSV et comparatifs (plus/moins)
- Import automatique Areas/Entities depuis HA
- Mode dry-run pour tests
**Risques/Plan B** : Fallback règles simples si NLU complexe échoue

#### T2.4 - Client TTS
**ID** : T2.4  
**Titre** : Client TTS vers Piper T630  
**Description** : Connexion Wyoming vers Piper T630, gestion queue, playback I²S  
**Dépendances** : T2.1 terminé, Piper T630 opérationnel  
**Scripts envisagés** : Service systemd `bender-tts-client`  
**Critères Done** : 
- Connexion Wyoming stable vers T630
- Queue TTS avec priorités
- Playback audio via I²S sans coupures
- Gestion erreurs et reconnexion auto
**Risques/Plan B** : TTS local Pi si T630 indisponible (Piper léger)

#### T2.5 - Client LEDs MQTT
**ID** : T2.5  
**Titre** : Client MQTT pour contrôle LEDs ESP32  
**Description** : Publication topics bender/led/state|viseme|env|config, sync avec TTS  
**Dépendances** : ESP32 firmware opérationnel  
**Scripts envisagés** : Service systemd `bender-leds-client`  
**Critères Done** : 
- Topics MQTT publiés selon spec
- Sync LEDs avec états (listen/think/speak)
- Visèmes ou RMS 20ms selon disponibilité
- Configuration palettes persistante
**Risques/Plan B** : Fallback RMS si visèmes indisponibles

#### T2.6 - UI Web FastAPI+React
**ID** : T2.6  
**Titre** : Interface utilisateur complète HTTPS  
**Description** : Backend FastAPI, frontend React, WebSocket live, cert auto-signé  
**Dépendances** : Services Pi opérationnels  
**Scripts envisagés** : Service systemd `bender-ui`  
**Critères Done** : 
- Dashboard (état, métriques, logs live)
- Sections : Audio, Wake, ASR/LLM/TTS, LEDs, Domotique, Sécurité
- Gestionnaire de voix (télécharger défaut + SHA-256, toggle Piper/RVC)
- HTTPS avec cert auto-signé
- Login/auth basique
**Risques/Plan B** : UI simplifiée si React complexe

#### T2.7 - Services systemd
**ID** : T2.7  
**Titre** : Configuration services systemd  
**Description** : bender-wake, bender-audio, bender-router, bender-tts-client, bender-leds-client, bender-ui, bender-metrics  
**Dépendances** : Tous services développés  
**Scripts envisagés** : `/scripts/pi/setup_systemd.sh`  
**Critères Done** : 
- 7 services systemd configurés
- Auto-start au boot
- Logs centralisés journald
- Restart automatique en cas d'échec
- Dépendances entre services respectées
**Risques/Plan B** : Scripts bash simples si systemd pose problème

### 🔥 EPIC 3 - Dev/Install ESP32

#### T3.1 - Firmware ESP32 base
**ID** : T3.1  
**Titre** : Développement firmware NeoPixelBus RMT  
**Description** : 3 chaînes indépendantes GPIO16/17/21, animations locales, persistance config  
**Dépendances** : T1.4 terminé, toolchain ESP32  
**Scripts envisagés** : PlatformIO ou Arduino IDE  
**Critères Done** : 
- 3 chaînes WS2812E contrôlées indépendamment
- Animations de base (solid, breathing, scan, blink)
- Persistance palette en EEPROM/SPIFFS
- Brightness réglable par chaîne
**Risques/Plan B** : FastLED si NeoPixelBus pose problème

#### T3.2 - Client MQTT ESP32
**ID** : T3.2  
**Titre** : Intégration MQTT pour contrôle distant  
**Description** : Topics bender/led/*, TLS, reconnexion auto, gestion retained  
**Dépendances** : T3.1 terminé, Mosquitto configuré  
**Scripts envisagés** : Lib PubSubClient ou WiFiClientSecure  
**Critères Done** : 
- Connexion MQTT TLS stable
- Souscription topics bender/led/state|viseme|env|config
- Publication état et ack
- Reconnexion automatique
- Gestion certificats TLS
**Risques/Plan B** : MQTT non-TLS temporaire si certificats posent problème

#### T3.3 - Animations synchronisées
**ID** : T3.3  
**Titre** : Implémentation sync visèmes et RMS  
**Description** : Interpolation visèmes A/E/I/O/U/M, RMS 20ms pour dents, états yeux  
**Dépendances** : T3.2 terminé  
**Scripts envisagés** : Algorithmes interpolation custom  
**Critères Done** : 
- Visèmes mappés sur LEDs dents (18 LEDs)
- RMS audio mappé sur intensité/couleur
- États yeux (idle/listen/think/speak/joy/anger/error/sleep)
- Latence < 60ms (RMS) mesurée
**Risques/Plan B** : Fallback RMS simple si visèmes trop complexes

### 🔥 EPIC 4 - Dev/Install T630

#### T4.1 - Setup Docker WSL2 T630
**ID** : T4.1  
**Titre** : Configuration environnement Docker sur Windows Server 2022  
**Description** : WSL2, Docker Desktop ou Docker CE, compose, volumes persistants  
**Dépendances** : Accès WinRM T630  
**Scripts envisagés** : `/scripts/t630/docker_bootstrap.ps1`  
**Critères Done** : 
- WSL2 installé et fonctionnel
- Docker opérationnel (test hello-world)
- Docker Compose disponible
- Volumes persistants configurés
- GPU accessible si présent (nvidia-docker)
**Risques/Plan B** : Docker sur Windows natif si WSL2 pose problème

#### T4.2 - Container Ollama
**ID** : T4.2  
**Titre** : Déploiement LLM Ollama avec modèle FR  
**Description** : Mistral-7B-Instruct Q4 ou Qwen2.5-7B-Instruct Q4, API REST, GPU si dispo  
**Dépendances** : T4.1 terminé  
**Scripts envisagés** : docker-compose.yml, script pull modèle  
**Critères Done** : 
- Container Ollama opérationnel
- Modèle FR téléchargé et chargé
- API REST accessible depuis Pi
- GPU utilisé si disponible
- Réponses cohérentes en français
**Risques/Plan B** : Modèle plus léger si ressources insuffisantes

#### T4.3 - Container Piper TTS
**ID** : T4.3  
**Titre** : Déploiement TTS Piper avec Wyoming  
**Description** : Container Piper, protocole Wyoming, voix FR par défaut à télécharger  
**Dépendances** : T4.1 terminé  
**Scripts envisagés** : docker-compose.yml, script téléchargement voix  
**Critères Done** : 
- Container Piper Wyoming opérationnel
- Protocole Wyoming accessible depuis Pi
- Voix FR par défaut prête (voir T4.5)
- Génération audio stable et rapide
**Risques/Plan B** : TTS alternatif (espeak-ng) si Piper pose problème

#### T4.4 - Container faster-whisper ASR
**ID** : T4.4  
**Titre** : Déploiement ASR faster-whisper avec Wyoming  
**Description** : Container faster-whisper, streaming, CUDA si GPU, modèle FR  
**Dépendances** : T4.1 terminé  
**Scripts envisagés** : docker-compose.yml, config streaming  
**Critères Done** : 
- Container faster-whisper Wyoming opérationnel
- Streaming audio depuis Pi fonctionnel
- CUDA utilisé si GPU disponible
- Modèle FR chargé et performant
- Latence ASR acceptable (<500ms)
**Risques/Plan B** : Modèle plus léger si performances insuffisantes

#### T4.5 - Téléchargement voix Piper FR par défaut
**ID** : T4.5  
**Titre** : Installation voix FR officielle avec vérification SHA-256  
**Description** : Script téléchargement voix FR Piper officielle, version pinnée, checksum vérifié, voice-id enregistré  
**Dépendances** : T4.3 en cours  
**Scripts envisagés** : `/scripts/t630/piper_get_voice.ps1` et `.sh`  
**Critères Done** : 
- Voix FR officielle téléchargée depuis source Piper
- Version pinnée (ex: fr-default@1.2.3)
- SHA-256 vérifié et enregistré
- Fichiers placés dans volume Docker piper:/data
- voice-id configuré dans Piper
- Test génération audio réussi
**Risques/Plan B** : Voix alternative si officielle indisponible

### 🔥 EPIC 5 - Tests maquette

#### T5.1 - Tests latences
**ID** : T5.1  
**Titre** : Mesure latences bout-en-bout  
**Description** : Domotique <1.5s médiane, conversation 2.5-3s, métriques HA  
**Dépendances** : E2, E3, E4 terminés  
**Scripts envisagés** : Scripts de test automatisés  
**Critères Done** : 
- Latence domotique mesurée <1.5s (médiane sur 50 tests)
- Latence conversation mesurée 2.5-3s (médiane)
- Métriques lat_asr/llm/tts dans HA
- Graphiques et logs de performance
**Risques/Plan B** : Optimisations si latences dépassées

#### T5.2 - Tests WER et faux réveils
**ID** : T5.2  
**Titre** : Validation reconnaissance vocale  
**Description** : WER en conditions silence/TV faible/forte, faux réveils/h  
**Dépendances** : T5.1 terminé  
**Scripts envisagés** : Corpus de test, mesures automatisées  
**Critères Done** : 
- WER mesurée en 3 conditions (silence/TV faible/forte)
- Faux réveils/h < seuil acceptable (à définir)
- AEC stable sans larsen
- VAD correctement calibré
**Risques/Plan B** : Ajustement paramètres AEC/VAD

#### T5.3 - Tests synchronisation LEDs
**ID** : T5.3  
**Titre** : Validation sync LEDs <60ms  
**Description** : Mesure latence LEDs dents avec RMS ou visèmes, sync yeux  
**Dépendances** : T5.1 terminé  
**Scripts envisagés** : Mesure avec oscilloscope ou caméra haute vitesse  
**Critères Done** : 
- Latence LEDs dents <60ms (RMS) mesurée
- Sync visèmes si disponibles
- États yeux cohérents avec pipeline
- Pas de scintillement ou artefacts
**Risques/Plan B** : Optimisation firmware ESP32 si latence excessive

### 🔥 EPIC 7 - Paramétrages finaux

#### T7.1 - Configuration persona Bender
**ID** : T7.1  
**Titre** : Paramétrage persona sarcastique FR  
**Description** : Prompts système, curseur impertinence UI, filtrage anti-haine ciblé  
**Dépendances** : LLM opérationnel  
**Scripts envisagés** : Templates prompts, config UI  
**Critères Done** : 
- Persona Bender sarcastique en français
- Curseur impertinence fonctionnel
- Filtrage minimal anti-haine
- Réponses cohérentes avec le personnage
**Risques/Plan B** : Persona plus neutre si problèmes

#### T7.2 - Mémoire longue
**ID** : T7.2  
**Titre** : Implémentation mémoire persistante  
**Description** : SQLite + embeddings, préférences utilisateur, scènes HA favorites, UI éditable  
**Dépendances** : UI opérationnelle  
**Scripts envisagés** : Base SQLite, API embeddings  
**Critères Done** : 
- Base SQLite mémoire longue
- Embeddings pour recherche sémantique
- Préférences utilisateur persistées
- Scènes/routines HA favorites
- Interface UI pour édition/purge
**Risques/Plan B** : Mémoire simple key-value si embeddings complexes

#### T7.3 - Configuration TLS/ACL
**ID** : T7.3  
**Titre** : Sécurisation MQTT et UI  
**Description** : Certificats auto-signés, ACL Mosquitto strictes, comptes séparés  
**Dépendances** : Mosquitto accessible  
**Scripts envisagés** : `/scripts/mqtt/mosquitto_tls_and_acl.sh`  
**Critères Done** : 
- Certificats TLS générés et déployés
- ACL Mosquitto configurées (Pi/ESP32/T630)
- UI HTTPS avec cert auto-signé
- Comptes MQTT séparés par rôle
- Tests connexions sécurisées OK
**Risques/Plan B** : Configuration manuelle si scripts échouent

### 🔥 EPIC 8 - Évolution v1.1 RVC

#### T8.1 - Intégration RVC pipeline
**ID** : T8.1  
**Titre** : Développement Voice Conversion après Piper  
**Description** : Pipeline Texte→Piper→RVC→HP, API locale, toggle UI  
**Dépendances** : v1 livrée et validée  
**Scripts envisagés** : Container RVC, API REST  
**Critères Done** : 
- Pipeline RVC intégré après Piper
- API locale pour conversion temps réel
- Toggle UI Piper pur / Piper→RVC
- Latence acceptable (<500ms ajout)
- Visèmes conservés depuis Piper
**Risques/Plan B** : RVC offline si temps réel impossible

#### T8.2 - Entraînement modèle RVC
**ID** : T8.2  
**Titre** : Entraînement avec samples utilisateur  
**Description** : 10-30 min extraits FR propres, nettoyage, entraînement T630  
**Dépendances** : T8.1 terminé, samples utilisateur  
**Scripts envisagés** : Pipeline preprocessing + training  
**Critères Done** : 
- Dataset 10-30 min samples FR nettoyés
- Entraînement RVC sur T630 (GPU recommandé)
- Modèle RVC fonctionnel et testé
- Qualité voix acceptable
- Export/import profil voix UI
**Risques/Plan B** : Modèle pré-entraîné si entraînement échoue

---

## Légende statuts
- 🔴 Pending : À faire
- 🟡 In Progress : En cours
- 🟢 Done : Terminé
- ❌ Blocked : Bloqué

## PRÉREQUIS (à valider avant Phase 1)

- [ ] **Accès machines** : SSH Pi5, WinRM/RDP T630, USB ESP32
- [ ] **Home Assistant** : Instance opérationnelle + Mosquitto
- [ ] **Matériel** : Pi5, ESP32, 2×INMP441, 2×MAX98357A, LEDs WS2812E, HPs 4Ω, alim 5V/8A
- [ ] **Réseau** : VLAN/firewall configurés, certificats TLS prêts
- [ ] **Voix TTS** : Accès aux voix Piper FR officielles + checksums
- [x] **Documentation câblage** : Schémas détaillés créés (CABLAGE.md)

## Prochaines actions
1. Valider pré-requis (IPs, accès, matériel)
2. Commencer par EPIC 1 (Maquette & câblage)
3. Paralléliser EPIC 2/3/4 une fois maquette OK

**Dernière mise à jour** : $(date)