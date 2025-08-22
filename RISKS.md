# RISKS - Assistant Vocal « Bender » v1.2

## Matrice des risques

**Légende probabilité** : 🟢 Faible (1-2) | 🟡 Moyenne (3) | 🔴 Élevée (4-5)  
**Légende impact** : 🟢 Mineur | 🟡 Modéré | 🔴 Critique

---

## Risques techniques

### R1 - I²S full-duplex instable
**Probabilité** : 🟡 3/5  
**Impact** : 🔴 Critique  
**Description** : Le Pi5 peut avoir des difficultés avec l'I²S full-duplex (capture + playback simultanés)  
**Symptômes** : Larsen, audio haché, devices non détectés  
**Mitigation** : 
- Plan B prévu : DAC USB pour sortie audio + ampli analogique
- Tests précoces avec `arecord` + `speaker-test` simultanés
- Paramètres PipeWire/ALSA ajustables
**Référence** : Section 4 "Audio — pinouts & traitements", Plan B explicite

### R2 - AEC WebRTC inefficace
**Probabilité** : 🟡 3/5  
**Impact** : 🟡 Modéré  
**Description** : L'AEC peut ne pas éliminer suffisamment l'écho, causant du larsen  
**Symptômes** : Larsen, wake words parasites, reconnaissance dégradée  
**Mitigation** : 
- Calibration fine des paramètres AEC
- Fallback sans AEC si nécessaire
- Positionnement optimal mics/HP
- Tests avec différents niveaux TV
**Référence** : Section 4, critères tests section 13

### R3 - Latences dépassées
**Probabilité** : 🟡 3/5  
**Impact** : 🟡 Modéré  
**Description** : Latences > objectifs (1.5s domotique, 2.5-3s conversation)  
**Causes** : Réseau, compute T630, pipeline audio  
**Mitigation** : 
- Métriques détaillées par composant
- Optimisation modèles (quantization, taille)
- Cache/préchargement intelligent
- Fallback modèles légers sur Pi
**Référence** : Section 13 "Tests & critères d'acceptation"

### R4 - Faux réveils excessifs
**Probabilité** : 🟡 3/5  
**Impact** : 🟡 Modéré  
**Description** : Wake word "Bender" détecté trop souvent (TV, conversations)  
**Mitigation** : 
- Seuils de sensibilité ajustables UI
- Modèle wake word custom si nécessaire
- VAD post-wake pour validation
- Timeout configurable
**Référence** : Section 6, métriques "faux réveils/h"

### R5 - Sync LEDs dégradée
**Probabilité** : 🟡 3/5  
**Impact** : 🟢 Mineur  
**Description** : Latence LEDs > 60ms, désynchronisation visèmes  
**Causes** : MQTT, WiFi ESP32, traitement RMT  
**Mitigation** : 
- Optimisation firmware ESP32
- Fallback RMS si visèmes complexes
- Buffer local ESP32 pour lissage
- Tests avec oscilloscope/caméra
**Référence** : Section 5 "LEDs — pinouts & effets", critères <60ms

---

## Risques matériels

### R6 - Alimentation LEDs insuffisante
**Probabilité** : 🟢 2/5  
**Impact** : 🟡 Modéré  
**Description** : 5V/5A insuffisant pour 36 LEDs WS2812E à pleine puissance  
**Calcul** : 36 LEDs × 60mA max = 2.16A (OK), mais pics possibles  
**Mitigation** : 
- Brightness max 40% par défaut
- Condo 1000µF pour pics
- Fusible 2.5-3A protection
- Monitoring courant si possible
**Référence** : Section 5, alim 5V/5A spécifiée

### R7 - Surchauffe T630
**Probabilité** : 🟢 2/5  
**Impact** : 🟡 Modéré  
**Description** : T630 surchauffe avec ASR+LLM+TTS simultanés  
**Mitigation** : 
- Monitoring température via métriques HA
- Throttling automatique si >seuil
- Ventilation serveur vérifiée
- Modèles moins gourmands si nécessaire
**Référence** : Section 6, métriques "CPU/temp T630"

### R8 - Défaillance microSD Pi
**Probabilité** : 🟡 3/5  
**Impact** : 🔴 Critique  
**Description** : Corruption microSD par écritures fréquentes (logs, métriques)  
**Mitigation** : 
- MicroSD U3 haute qualité
- Logs avec rotation et quotas
- Backup config automatique
- Procédure restauration documentée
**Référence** : Section 2, microSD 64GB U3 spécifiée

---

## Risques réseau/sécurité

### R9 - Certificats TLS expirés
**Probabilité** : 🟡 3/5  
**Impact** : 🟡 Modéré  
**Description** : Certs auto-signés expirés, connexions MQTT/UI bloquées  
**Mitigation** : 
- Renouvellement automatique certs
- Monitoring expiration
- Procédure manuelle de secours
- Durée de vie certs suffisante (1-2 ans)
**Référence** : Section 12 "Sécurité & vie privée"

### R10 - Panne réseau isolant T630
**Probabilité** : 🟢 2/5  
**Impact** : 🔴 Critique  
**Description** : T630 inaccessible, plus d'ASR/LLM/TTS  
**Mitigation** : 
- Fallback TTS local Pi (Piper léger)
- Fallback LLM local Pi (Phi-3-mini)
- Détection panne et basculement auto
- Monitoring réseau continu
**Référence** : Section 10, fallback Pi mentionné

---

## Risques projet

### R11 - Voix Piper par défaut indisponible
**Probabilité** : 🟢 2/5  
**Impact** : 🟡 Modéré  
**Description** : Voix FR officielle non téléchargeable ou corrompue  
**Mitigation** : 
- Plusieurs sources/miroirs
- Vérification SHA-256 stricte
- Voix de secours pré-téléchargée
- Documentation sources alternatives
**Référence** : Section 7.1, reproductibilité critique

### R12 - Complexité RVC v1.1
**Probabilité** : 🟡 3/5  
**Impact** : 🟢 Mineur  
**Description** : Voice Conversion trop complexe/lente pour temps réel  
**Mitigation** : 
- RVC optionnel (v1 fonctionne sans)
- Tests performance précoces
- Fallback RVC offline si nécessaire
- Modèles RVC légers privilégiés
**Référence** : Section 7.2, évolution v1.1

### R13 - Intégration Home Assistant
**Probabilité** : 🟡 3/5  
**Impact** : 🟡 Modéré  
**Description** : API HA changée, entités non importées, ACL Mosquitto bloquantes  
**Mitigation** : 
- Version HA documentée et testée
- Import entités avec gestion erreurs
- Mode dry-run pour tests
- Configuration ACL progressive
**Référence** : Section 9 "Domotique (NLU/HA)"

---

## Actions de mitigation prioritaires

1. **Tests I²S précoces** (R1) : Valider full-duplex dès maquette
2. **Plan B audio** (R1) : Préparer DAC USB + ampli
3. **Métriques complètes** (R3, R7) : Latences, CPU, temp dès dev
4. **Backup/restore** (R8) : Procédures automatisées
5. **Fallbacks locaux** (R10) : TTS/LLM Pi en secours

---

## Suivi des risques

**Révision** : Hebdomadaire pendant dev, quotidienne pendant tests  
**Escalation** : Risque critique non mitigé → arrêt phase  
**Documentation** : Incidents et résolutions dans CHANGELOG.md