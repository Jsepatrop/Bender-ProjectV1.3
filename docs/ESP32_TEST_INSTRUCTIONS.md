# Instructions de test ESP32 - LEDs WS2812E

## Objectif
Valider le fonctionnement des LEDs WS2812E câblées sur l'ESP32 avec le firmware de test.

## Prérequis
- ESP32 câblé selon `docs/CABLAGE.md`
- Arduino IDE installé avec support ESP32
- Bibliothèque FastLED installée
- Câble USB pour programmer l'ESP32

## Installation de la bibliothèque FastLED

### Dans Arduino IDE :
1. Ouvrir **Outils** → **Gérer les bibliothèques**
2. Rechercher "**FastLED**"
3. Installer la version la plus récente (≥3.6.0)

### Ou via PlatformIO :
```ini
[env:esp32]
platform = espressif32
board = esp32dev
framework = arduino
lib_deps = fastled/FastLED@^3.6.0
```

## Configuration ESP32 dans Arduino IDE

1. **Gestionnaire de cartes** :
   - Fichier → Préférences
   - URLs supplémentaires : `https://dl.espressif.com/dl/package_esp32_index.json`
   - Outils → Type de carte → Gestionnaire de cartes
   - Rechercher "ESP32" et installer

2. **Sélection de la carte** :
   - Outils → Type de carte → ESP32 Arduino → **ESP32 Dev Module**
   - Port : sélectionner le port COM de l'ESP32

## Upload du firmware

1. Ouvrir le fichier `firmware/esp32_led_test.ino`
2. Vérifier la compilation (Ctrl+R)
3. Uploader sur l'ESP32 (Ctrl+U)
4. Ouvrir le **Moniteur série** (Ctrl+Shift+M)
5. Configurer la vitesse : **115200 baud**

## Tests de validation

### 1. Observation du moniteur série
Vous devriez voir :
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

### 2. Observation visuelle des LEDs

**Séquence attendue (cycle de ~15 secondes) :**

1. **Test couleurs globales** (6s) :
   - Toutes les LEDs en ROUGE (2s)
   - Toutes les LEDs en VERT (2s) 
   - Toutes les LEDs en BLEU (2s)

2. **Test par segments** (4.5s) :
   - Dents uniquement en JAUNE (1.5s)
   - Œil gauche uniquement en CYAN (1.5s)
   - Œil droit uniquement en MAGENTA (1.5s)

3. **Animation arc-en-ciel** (~3s) :
   - Dégradé de couleurs fluide sur tous les segments

4. **Clignotement blanc** (3s) :
   - 5 clignotements blanc/noir (300ms chacun)

5. **Pause** (3s) :
   - Toutes LEDs éteintes

### 3. Critères de validation

✅ **SUCCÈS si :**
- Messages série s'affichent correctement
- Les 3 segments (dents + 2 yeux) s'allument
- Couleurs conformes à la séquence
- Pas de scintillement ou comportement erratique
- Animation fluide

❌ **ÉCHEC si :**
- Aucune LED ne s'allume
- Un ou plusieurs segments ne fonctionnent pas
- Couleurs incorrectes ou aléatoires
- Scintillement permanent
- Redémarrage en boucle de l'ESP32

## Diagnostic des problèmes

### Aucune LED ne s'allume
1. **Vérifier l'alimentation 5V** :
   - Multimètre sur les rails 5V/GND
   - Tension stable entre 4.8V et 5.2V

2. **Vérifier les connexions GPIO** :
   - GPIO16 → Dents (avec résistance 330Ω)
   - GPIO17 → Œil gauche (avec résistance 330Ω)
   - GPIO21 → Œil droit (avec résistance 330Ω)

3. **Tester avec une seule LED** :
   - Déconnecter 2 segments sur 3
   - Tester segment par segment

### Un segment ne fonctionne pas
1. **Vérifier la résistance 330Ω** sur la ligne de données
2. **Contrôler la soudure** du connecteur
3. **Tester la continuité** GPIO → première LED du segment
4. **Vérifier l'alimentation** 5V/GND du segment défaillant

### Comportement erratique
1. **Condensateur 1000µF** bien connecté sur l'alimentation 5V
2. **Masse commune** entre ESP32 et alimentation LEDs
3. **Longueur des câbles** : minimiser les connexions longues
4. **Interférences** : éloigner des sources de bruit électrique

### ESP32 redémarre en boucle
1. **Consommation excessive** : vérifier l'alimentation 5V/5A
2. **Court-circuit** : contrôler toutes les soudures
3. **Fusible déclenché** : vérifier le fusible 2.5-3A

## Plan B - Test minimal

Si le test complet échoue, modifier temporairement le code :

```cpp
// Réduire le nombre de LEDs pour test
#define NUM_LEDS_TEETH 1    // Au lieu de 18
#define NUM_LEDS_EYE_LEFT 1 // Au lieu de 9  
#define NUM_LEDS_EYE_RIGHT 1// Au lieu de 9

// Réduire la luminosité
FastLED.setBrightness(10);  // Au lieu de 50
```

## Résultats attendus

Après validation réussie :
- **Consommation mesurée** : <500mA à luminosité 50
- **Latence d'affichage** : <20ms
- **Stabilité** : aucun redémarrage sur 10 minutes
- **Segments fonctionnels** : 3/3 (dents + 2 yeux)

## Prochaines étapes

Une fois le test validé :
1. Documenter les résultats dans `METRICS.md`
2. Marquer la tâche T1.4 comme terminée dans `TODO.md`
3. Passer au développement du firmware MQTT final
4. Commencer la configuration du Raspberry Pi 5

---

**Note** : Ce test valide uniquement le matériel. Le firmware final intégrera MQTT, animations complexes et synchronisation avec le pipeline audio.