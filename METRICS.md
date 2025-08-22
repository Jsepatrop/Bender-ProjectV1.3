# METRICS - Assistant Vocal « Bender » v1.2

## Métriques de performance

### Latences (objectifs critiques)

#### Domotique
**Métrique** : `lat_domotique_ms`  
**Objectif** : < 1500 ms (médiane sur 50 mesures)  
**Mesure** : Wake détecté → action HA exécutée  
**Composants** : Wake + ASR + NLU + MQTT→HA  
**Collecte** : Service bender-metrics, export vers HA  
**Seuils** : 
- 🟢 < 1200 ms : Excellent
- 🟡 1200-1500 ms : Acceptable
- 🔴 > 1500 ms : Critique

#### Conversation
**Métrique** : `lat_conversation_ms`  
**Objectif** : 2500-3000 ms (médiane)  
**Mesure** : Wake détecté → première syllabe TTS  
**Composants** : Wake + ASR + LLM + TTS + audio out  
**Seuils** : 
- 🟢 < 2500 ms : Excellent
- 🟡 2500-3500 ms : Acceptable
- 🔴 > 3500 ms : Critique

#### Composants détaillés
**Métriques** : `lat_asr_ms`, `lat_llm_ms`, `lat_tts_ms`  
**Objectifs** : 
- ASR : < 500 ms (streaming)
- LLM : < 1500 ms (réponse courte)
- TTS : < 800 ms (phrase moyenne)
**Utilité** : Debug et optimisation ciblée

### LEDs et synchronisation

#### Sync LEDs dents
**Métrique** : `led_sync_latency_ms`  
**Objectif** : < 60 ms (RMS sur 100 mesures)  
**Mesure** : Signal audio → changement LED visible  
**Méthode** : Oscilloscope ou caméra haute vitesse  
**Seuils** : 
- 🟢 < 40 ms : Excellent
- 🟡 40-60 ms : Acceptable
- 🔴 > 60 ms : Critique

#### Visèmes (si disponibles)
**Métrique** : `viseme_accuracy_pct`  
**Objectif** : > 80% correspondance phonème→LED  
**Mesure** : Validation manuelle échantillon  
**Fallback** : RMS si visèmes < 70%

### Qualité reconnaissance

#### Word Error Rate (WER)
**Métrique** : `wer_percent`  
**Objectifs** : 
- Silence : < 5%
- TV faible : < 10%
- TV forte : < 20%
**Corpus** : 100 phrases FR variées  
**Mesure** : (Substitutions + Insertions + Suppressions) / Mots totaux

#### Faux réveils
**Métrique** : `false_wake_per_hour`  
**Objectif** : < 2 faux réveils/h (TV normale)  
**Conditions** : 
- Silence : < 0.5/h
- TV faible : < 1/h
- TV forte : < 3/h
**Mesure** : Wake détecté sans intention utilisateur

### Ressources système

#### CPU et température
**Métriques** : 
- `cpu_pi_percent`, `temp_pi_celsius`
- `cpu_t630_percent`, `temp_t630_celsius`
**Objectifs** : 
- CPU Pi : < 70% moyen, < 90% pic
- Temp Pi : < 70°C
- CPU T630 : < 80% moyen
- Temp T630 : < 80°C
**Collecte** : Toutes les 30s, moyennes 5min

#### Mémoire
**Métriques** : `ram_pi_mb`, `ram_t630_mb`  
**Objectifs** : 
- Pi : < 3GB utilisés (sur 4GB)
- T630 : < 80% RAM totale
**Alertes** : > 90% → risque swap/OOM

#### Réseau
**Métriques** : `network_latency_ms`, `mqtt_reconnects_count`  
**Objectifs** : 
- Latence Pi↔T630 : < 10 ms
- Reconnexions MQTT : < 1/jour
**Monitoring** : Ping continu, logs MQTT

---

## Métriques qualité

### Audio

#### Niveaux d'entrée
**Métriques** : `mic_level_db_front`, `mic_level_db_torse`  
**Objectifs** : 
- Signal parole : -20 à -10 dB
- Bruit de fond : < -40 dB
- Pas de saturation (> -3 dB)
**Affichage** : VU-mètres UI temps réel

#### AEC efficacité
**Métrique** : `aec_suppression_db`  
**Objectif** : > 20 dB suppression écho  
**Mesure** : Signal ref vs signal capturé  
**Validation** : Pas de larsen à volume normal

### TTS et voix

#### Voix par défaut
**Métriques** : 
- `voice_checksum_valid` : Boolean
- `voice_version` : String (ex: "fr-default@1.2.3")
- `voice_file_size_mb` : Taille modèle
**Validation** : SHA-256 vérifié au démarrage

#### Génération TTS
**Métriques** : 
- `tts_chars_per_second` : Vitesse génération
- `tts_audio_quality_score` : Évaluation subjective
**Objectifs** : 
- Vitesse : > 100 chars/s
- Qualité : > 7/10 (écoute humaine)

---

## Collecte et stockage

### Infrastructure
**Collecteur** : Service `bender-metrics` (Pi)  
**Stockage** : InfluxDB ou SQLite local  
**Export** : Home Assistant (sensors MQTT)  
**Rétention** : 
- Temps réel : 24h
- Moyennes 5min : 7 jours
- Moyennes 1h : 30 jours
- Moyennes 1j : 1 an

### Dashboard HA
**Graphiques** : 
- Latences (ligne temporelle)
- CPU/Temp (gauge + historique)
- WER et faux réveils (barres)
- LEDs sync (scatter plot)
**Alertes** : 
- Latence > seuil → notification
- Temp > 75°C → alerte
- Faux réveils > 5/h → warning

### UI Web intégrée
**Sections** : 
- Dashboard live (WebSocket)
- Historiques (graphiques 24h/7j)
- Tests manuels (boutons WER, latence)
- Export données (CSV, JSON)

---

## Tests LEDs ESP32

### Validation réussie - Test firmware esp32_led_test.ino

**Date**: 2025-01-21  
**Statut**: ✅ SUCCÈS COMPLET  
**Segments testés**: 3/3 fonctionnels

- **Dents** (GPIO16, 18 LEDs): ✅ Fonctionnel
- **Œil gauche** (GPIO17, 9 LEDs): ✅ Fonctionnel  
- **Œil droit** (GPIO21, 9 LEDs): ✅ Fonctionnel

**Séquences validées**:
- Couleurs globales (Rouge/Vert/Bleu): ✅
- Segments individuels (Jaune/Cyan/Magenta): ✅
- Animation arc-en-ciel: ✅
- Clignotement blanc: ✅

**Observations**:
- Aucun scintillement détecté
- Couleurs conformes aux spécifications
- ESP32 stable, pas de redémarrage
- Câblage GPIO 16/17/21 validé
- Résistances 330Ω et alimentation 5V opérationnelles

**Critères EPIC 1 atteints**: Maquette & câblage terminé avec succès

---

## Tests et validation

### Protocoles de test

#### Test latence domotique
1. Préparer 50 commandes variées
2. Chronométrer wake → action HA
3. Calculer médiane, P95, P99
4. Valider < 1500 ms médiane

#### Test WER
1. Corpus 100 phrases FR (courtes/longues)
2. 3 conditions : silence, TV faible, TV forte
3. Transcription automatique vs référence
4. Calcul WER par condition

#### Test faux réveils
1. Enregistrement 2h TV/radio FR
2. Comptage wake détectés
3. Validation manuelle (vrai/faux)
4. Calcul taux faux réveils/h

#### Test sync LEDs
1. Signal audio test (sweep, impulsions)
2. Mesure oscilloscope audio vs LED
3. 100 mesures, calcul RMS latence
4. Validation < 60 ms

### Critères d'acceptation
**v1 Release** : 
- ✅ Latence domotique < 1.5s (médiane)
- ✅ Latence conversation 2.5-3s
- ✅ WER silence < 5%, TV forte < 20%
- ✅ Faux réveils < 2/h
- ✅ LEDs sync < 60ms
- ✅ Voix défaut SHA-256 OK
- ✅ CPU Pi < 70%, Temp < 70°C
- ✅ Uptime services > 99%

**v1.1 RVC** : 
- ✅ Latence RVC < +500ms vs Piper pur
- ✅ Qualité voix RVC > 7/10
- ✅ Toggle UI fonctionnel
- ✅ Visèmes conservés

---

## Monitoring continu

### Alertes automatiques
**Critiques** : 
- Latence > 2× objectif
- Temp > 80°C
- Services down > 5min
- Faux réveils > 10/h

**Warnings** : 
- Latence > 1.2× objectif
- CPU > 80%
- WER dégradé > 20%
- Reconnexions MQTT fréquentes

### Rapports
**Quotidien** : Résumé métriques clés  
**Hebdomadaire** : Tendances et dégradations  
**Mensuel** : Bilan performance et optimisations

**Dernière mise à jour** : $(date)