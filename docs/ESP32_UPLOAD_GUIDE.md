# Guide d'upload ESP32 - Test LEDs WS2812E

## Firmware à uploader
**Fichier**: `firmware/esp32_led_test.ino`

## Configuration Arduino IDE 2.3.6

### 1. Sélection de la carte
- **Outils** → **Type de carte** → **ESP32 Arduino** → **ESP32 Dev Module**
- **Port** : Sélectionner **COM6** (votre ESP32)

### 2. Vérification de la bibliothèque FastLED
- **Outils** → **Gérer les bibliothèques**
- Rechercher "**FastLED**"
- Installer si pas déjà fait (version ≥3.6.0)

### 3. Upload du firmware
1. Ouvrir le fichier `firmware/esp32_led_test.ino`
2. **Vérifier** la compilation (Ctrl+R)
3. **Uploader** sur l'ESP32 (Ctrl+U)
4. Ouvrir le **Moniteur série** (Ctrl+Shift+M)
5. Configurer la vitesse : **115200 baud**

## Séquence de test attendue

### Messages série
```
=== Test LEDs Bender ESP32 ===
Initialisation des strips WS2812E...
Configuration terminée. Début des tests...

--- Cycle de test ---
Test 1: Toutes LEDs ROUGE
Test 2: Toutes LEDs VERT
Test 3: Toutes LEDs BLEU
Test 4: Segments individuels
  - Dents: JAUNE
  - Œil gauche: CYAN
  - Œil droit: MAGENTA
Test 5: Animation arc-en-ciel
Test 6: Clignotement blanc
Fin du cycle. Pause 3 secondes...
```

### Séquence visuelle (cycle ~18 secondes)

1. **Couleurs globales** (6 secondes) :
   - Toutes les LEDs en **ROUGE** (2s)
   - Toutes les LEDs en **VERT** (2s)
   - Toutes les LEDs en **BLEU** (2s)

2. **Segments individuels** (4.5 secondes) :
   - **Dents uniquement** en JAUNE (1.5s)
   - **Œil gauche uniquement** en CYAN (1.5s)
   - **Œil droit uniquement** en MAGENTA (1.5s)

3. **Animation arc-en-ciel** (~3 secondes) :
   - Dégradé de couleurs fluide sur tous les segments

4. **Clignotement blanc** (3 secondes) :
   - 5 clignotements blanc/noir (300ms chacun)

5. **Pause** (3 secondes) :
   - Toutes LEDs éteintes

## Critères de validation

### ✅ SUCCÈS si :
- Messages série s'affichent correctement
- Les **3 segments** s'allument (dents + 2 yeux)
- Couleurs conformes à la séquence
- Animation fluide, pas de scintillement
- Pas de redémarrage en boucle de l'ESP32

### ❌ ÉCHEC si :
- Aucune LED ne s'allume
- Un ou plusieurs segments ne fonctionnent pas
- Couleurs incorrectes ou aléatoires
- Scintillement permanent
- ESP32 redémarre en boucle

## Diagnostic rapide

### Si aucune LED ne s'allume :
1. Vérifier l'**alimentation 5V** (4.8-5.2V au multimètre)
2. Contrôler les **connexions GPIO** 16, 17, 21
3. Vérifier les **résistances 330Ω** sur les lignes de données

### Si un segment ne fonctionne pas :
1. Tester la **continuité** GPIO → première LED du segment
2. Vérifier l'**alimentation 5V/GND** du segment défaillant
3. Contrôler la **soudure** du connecteur

### Si comportement erratique :
1. Vérifier le **condensateur 1000µF** sur l'alimentation 5V
2. Contrôler la **masse commune** entre ESP32 et alimentation LEDs
3. Minimiser la **longueur des câbles**

## Après le test

### Si SUCCÈS :
- Laisser tourner 2-3 cycles complets pour vérifier la stabilité
- Noter les observations dans le chat
- Passer à l'étape suivante (firmware MQTT final)

### Si ÉCHEC :
- Noter le problème observé dans le chat
- Consulter la section diagnostic ci-dessus
- Possibilité de test avec moins de LEDs (modifier le code)

---

**Note** : Ce test valide uniquement le matériel. Le firmware final intégrera MQTT, animations complexes et synchronisation avec le pipeline audio.