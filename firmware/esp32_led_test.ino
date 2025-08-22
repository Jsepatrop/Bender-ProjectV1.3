/*
 * Test des LEDs WS2812E pour Assistant Vocal Bender
 * ESP32 - Test de validation du câblage
 * 
 * Câblage:
 * - GPIO16 (D16) -> Dents (18 LEDs)
 * - GPIO17 (D17) -> Œil gauche (9 LEDs) 
 * - GPIO21 (D21) -> Œil droit (9 LEDs)
 * 
 * Résistances 330Ω sur chaque ligne de données
 * Alimentation 5V commune pour toutes les LEDs
 */

#include <FastLED.h>

// Configuration des LEDs
#define NUM_LEDS_TEETH 18
#define NUM_LEDS_EYE_LEFT 9
#define NUM_LEDS_EYE_RIGHT 9

#define PIN_TEETH 16
#define PIN_EYE_LEFT 17
#define PIN_EYE_RIGHT 21

// Tableaux de LEDs
CRGB leds_teeth[NUM_LEDS_TEETH];
CRGB leds_eye_left[NUM_LEDS_EYE_LEFT];
CRGB leds_eye_right[NUM_LEDS_EYE_RIGHT];

void setup() {
  Serial.begin(115200);
  Serial.println("=== Test LEDs Bender ESP32 ===");
  Serial.println("Initialisation des strips WS2812E...");
  
  // Initialisation FastLED
  FastLED.addLeds<WS2812, PIN_TEETH, GRB>(leds_teeth, NUM_LEDS_TEETH);
  FastLED.addLeds<WS2812, PIN_EYE_LEFT, GRB>(leds_eye_left, NUM_LEDS_EYE_LEFT);
  FastLED.addLeds<WS2812, PIN_EYE_RIGHT, GRB>(leds_eye_right, NUM_LEDS_EYE_RIGHT);
  
  // Luminosité réduite pour les tests
  FastLED.setBrightness(50);
  
  Serial.println("Configuration terminée. Début des tests...");
}

void loop() {
  Serial.println("\n--- Cycle de test ---");
  
  // Test 1: Toutes les LEDs en rouge
  Serial.println("Test 1: Toutes LEDs ROUGE");
  fill_all_leds(CRGB::Red);
  FastLED.show();
  delay(2000);
  
  // Test 2: Toutes les LEDs en vert
  Serial.println("Test 2: Toutes LEDs VERT");
  fill_all_leds(CRGB::Green);
  FastLED.show();
  delay(2000);
  
  // Test 3: Toutes les LEDs en bleu
  Serial.println("Test 3: Toutes LEDs BLEU");
  fill_all_leds(CRGB::Blue);
  FastLED.show();
  delay(2000);
  
  // Test 4: Test individuel par segment
  Serial.println("Test 4: Segments individuels");
  clear_all_leds();
  
  // Dents en jaune
  Serial.println("  - Dents: JAUNE");
  fill_segment(leds_teeth, NUM_LEDS_TEETH, CRGB::Yellow);
  FastLED.show();
  delay(1500);
  
  // Œil gauche en cyan
  Serial.println("  - Œil gauche: CYAN");
  fill_segment(leds_eye_left, NUM_LEDS_EYE_LEFT, CRGB::Cyan);
  FastLED.show();
  delay(1500);
  
  // Œil droit en magenta
  Serial.println("  - Œil droit: MAGENTA");
  fill_segment(leds_eye_right, NUM_LEDS_EYE_RIGHT, CRGB::Magenta);
  FastLED.show();
  delay(1500);
  
  // Test 5: Animation arc-en-ciel
  Serial.println("Test 5: Animation arc-en-ciel");
  rainbow_animation();
  
  // Test 6: Clignotement blanc
  Serial.println("Test 6: Clignotement blanc");
  for(int i = 0; i < 5; i++) {
    fill_all_leds(CRGB::White);
    FastLED.show();
    delay(300);
    clear_all_leds();
    FastLED.show();
    delay(300);
  }
  
  // Pause avant le prochain cycle
  Serial.println("Fin du cycle. Pause 3 secondes...");
  clear_all_leds();
  FastLED.show();
  delay(3000);
}

// Fonctions utilitaires
void fill_all_leds(CRGB color) {
  fill_segment(leds_teeth, NUM_LEDS_TEETH, color);
  fill_segment(leds_eye_left, NUM_LEDS_EYE_LEFT, color);
  fill_segment(leds_eye_right, NUM_LEDS_EYE_RIGHT, color);
}

void clear_all_leds() {
  fill_all_leds(CRGB::Black);
}

void fill_segment(CRGB* leds, int num_leds, CRGB color) {
  for(int i = 0; i < num_leds; i++) {
    leds[i] = color;
  }
}

void rainbow_animation() {
  for(int hue = 0; hue < 256; hue += 5) {
    // Dents
    for(int i = 0; i < NUM_LEDS_TEETH; i++) {
      leds_teeth[i] = CHSV(hue + (i * 10), 255, 255);
    }
    // Yeux
    for(int i = 0; i < NUM_LEDS_EYE_LEFT; i++) {
      leds_eye_left[i] = CHSV(hue + (i * 20), 255, 255);
      leds_eye_right[i] = CHSV(hue + (i * 20), 255, 255);
    }
    FastLED.show();
    delay(50);
  }
}

/*
 * Instructions de test:
 * 
 * 1. Compiler et uploader ce code sur l'ESP32
 * 2. Ouvrir le moniteur série (115200 baud)
 * 3. Observer les séquences de test:
 *    - Rouge/Vert/Bleu sur toutes les LEDs
 *    - Test individuel par segment (dents, œil gauche, œil droit)
 *    - Animation arc-en-ciel
 *    - Clignotement blanc
 * 
 * Validation attendue:
 * - Toutes les LEDs s'allument selon les couleurs programmées
 * - Chaque segment (dents, yeux) fonctionne indépendamment
 * - Pas de scintillement ou comportement erratique
 * - Messages de debug dans le moniteur série
 * 
 * En cas de problème:
 * - Vérifier l'alimentation 5V (suffisante pour ~36 LEDs)
 * - Contrôler les résistances 330Ω sur les lignes de données
 * - Vérifier les connexions GPIO 16, 17, 21
 * - Tester avec une seule LED par segment d'abord
 */