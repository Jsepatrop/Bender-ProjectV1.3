# Schéma de câblage détaillé - Assistant Vocal Bender

## Vue d'ensemble du système

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Raspberry     │    │      ESP32      │    │   Dell T630     │
│     Pi 5        │    │                 │    │  (Windows+WSL2) │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │Audio Pipeline│ │    │ │LED Controller│ │    │ │AI Services  │ │
│ │I²S+AEC+VAD  │ │    │ │WS2812E×3    │ │    │ │ASR+LLM+TTS  │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Home Assistant  │
                    │ + Mosquitto     │
                    │   (MQTTS+ACL)   │
                    └─────────────────┘
```

## 1. Raspberry Pi 5 - Audio I²S

### Pinout RPi5 (GPIO Header 40 pins)

<mcreference link="https://learn.adafruit.com/adafruit-max98357-i2s-class-d-mono-amp/raspberry-pi-wiring" index="1">1</mcreference> <mcreference link="https://learn.adafruit.com/adafruit-max98357-i2s-class-d-mono-amp/pinouts" index="2">2</mcreference>

```
     3V3  (1) ● ● (2)  5V
   GPIO2  (3) ● ● (4)  5V
   GPIO3  (5) ● ● (6)  GND
   GPIO4  (7) ● ● (8)  GPIO14
     GND  (9) ● ● (10) GPIO15
  GPIO17 (11) ● ● (12) GPIO18 ← BCLK (I²S)
  GPIO27 (13) ● ● (14) GND
  GPIO22 (15) ● ● (16) GPIO23
     3V3 (17) ● ● (18) GPIO24
  GPIO10 (19) ● ● (20) GND
   GPIO9 (21) ● ● (22) GPIO25
  GPIO11 (23) ● ● (24) GPIO8
     GND (25) ● ● (26) GPIO7
   GPIO0 (27) ● ● (28) GPIO1
   GPIO5 (29) ● ● (30) GND
   GPIO6 (31) ● ● (32) GPIO12
  GPIO13 (33) ● ● (34) GND
  GPIO19 (35) ● ● (36) GPIO16 ← LRCLK (I²S)
  GPIO26 (37) ● ● (38) GPIO20 ← DIN Microphones
     GND (39) ● ● (40) GPIO21 ← DOUT Amplificateurs
```

### Connexions I²S

**Signaux I²S partagés :**
- **BCLK** (Bit Clock) : GPIO18 (pin 12)
- **LRCLK** (Left/Right Clock) : GPIO19 (pin 35)
- **DIN** (Data Input - Microphones) : GPIO20 (pin 38)
- **DOUT** (Data Output - Amplificateurs) : GPIO21 (pin 40)

## 2. Microphones INMP441 (×2)

<mcreference link="https://learn.adafruit.com/adafruit-max98357-i2s-class-d-mono-amp/raspberry-pi-wiring" index="1">1</mcreference>

### Schéma de connexion

```
┌─────────────────┐    ┌─────────────────┐
│   INMP441 #1    │    │   INMP441 #2    │
│   (FRONT)       │    │   (TORSE)       │
├─────────────────┤    ├─────────────────┤
│ VDD → 3.3V      │    │ VDD → 3.3V      │
│ GND → GND       │    │ GND → GND       │
│ L/R → GND       │    │ L/R → 3.3V      │
│ WS  → GPIO19    │    │ WS  → GPIO19    │
│ SCK → GPIO18    │    │ SCK → GPIO18    │
│ SD  → GPIO20    │    │ SD  → GPIO20    │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────────────────┘
                   │
              Bus I²S partagé
                   │
         ┌─────────────────┐
         │ Raspberry Pi 5  │
         │ GPIO18,19,20    │
         └─────────────────┘
```

### Détail des connexions

| Signal | INMP441 Pin | RPi5 GPIO | RPi5 Pin | Fonction |
|--------|-------------|-----------|----------|----------|
| VDD    | VDD         | 3.3V      | 1 ou 17  | Alimentation |
| GND    | GND         | GND       | 6,9,14,20,25,30,34,39 | Masse |
| L/R    | L/R         | GND/3.3V  | Voir ci-dessous | Sélection canal |
| WS     | WS          | GPIO19    | 35       | Left/Right Clock |
| SCK    | SCK         | GPIO18    | 12       | Bit Clock |
| SD     | SD          | GPIO20    | 38       | Serial Data |

**Configuration L/R :**
- **INMP441 #1 (Front)** : L/R → GND (canal gauche)
- **INMP441 #2 (Torse)** : L/R → 3.3V (canal droit)

## 3. Amplificateurs MAX98357A (×2)

<mcreference link="https://learn.adafruit.com/adafruit-max98357-i2s-class-d-mono-amp/pinouts" index="2">2</mcreference>

### Schéma de connexion

```
┌─────────────────┐    ┌─────────────────┐
│  MAX98357A #1   │    │  MAX98357A #2   │
│                 │    │                 │
├─────────────────┤    ├─────────────────┤
│ Vin  → 5V       │    │ Vin  → 5V       │
│ GND  → GND      │    │ GND  → GND      │
│ LRC  → GPIO19   │    │ LRC  → GPIO19   │
│ BCLK → GPIO18   │    │ BCLK → GPIO18   │
│ DIN  → GPIO21   │    │ DIN  → GPIO21   │
│ GAIN → NC       │    │ GAIN → NC       │
│ SD   → Vin      │    │ SD   → Vin      │
│ +/-  → HP 4Ω    │    │ +/-  → HP 4Ω    │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────────────────┘
                   │
              Bus I²S partagé
                   │
         ┌─────────────────┐
         │ Raspberry Pi 5  │
         │ GPIO18,19,21    │
         └─────────────────┘
```

### Détail des connexions

| Signal | MAX98357A Pin | RPi5 GPIO | RPi5 Pin | Fonction |
|--------|---------------|-----------|----------|----------|
| Vin    | Vin           | 5V Ext    | -        | Alimentation 5V |
| GND    | GND           | GND       | 6,9,14,20,25,30,34,39 | Masse |
| LRC    | LRC           | GPIO19    | 35       | Left/Right Clock |
| BCLK   | BCLK          | GPIO18    | 12       | Bit Clock |
| DIN    | DIN           | GPIO21    | 40       | Serial Data |
| GAIN   | GAIN          | NC        | -        | 9dB par défaut |
| SD     | SD            | Vin       | -        | Mode stéréo mixé |
| +/-    | Speaker Out   | HP 4Ω     | -        | Sortie haut-parleur |

**Notes importantes :**
- Alimentation 5V externe recommandée (jusqu'à 3W par ampli)
- Haut-parleurs 4Ω minimum
- SD connecté à Vin = sortie (L+R)/2 (stéréo mixé)

## 4. ESP32 - Contrôleur LEDs

<mcreference link="https://lastminuteengineers.com/esp32-wled-tutorial/" index="1">1</mcreference> <mcreference link="https://esp32io.com/tutorials/esp32-ws2812b-led-strip" index="3">3</mcreference>

### Pinout ESP32 (30 pins)

```
                     ┌─────────────────┐
                     │      ESP32      │
                     │   WROOM-32      │
                     ├─────────────────┤
               EN  1 │●               ●│ 30  GND
            VP/36  2 │●               ●│ 29  VN/39
            VN/39  3 │●               ●│ 28  D35
             D35  4 │●               ●│ 27  D33
             D32  5 │●               ●│ 26  D25
             D33  6 │●               ●│ 25  D26
             D25  7 │●               ●│ 24  D27
             D26  8 │●               ●│ 23  D14
             D27  9 │●               ●│ 22  D12
             D14 10 │●               ●│ 21  D13
             D12 11 │●               ●│ 20  GND
             D13 12 │●               ●│ 19  VIN
             GND 13 │●               ●│ 18  D23
             VIN 14 │●               ●│ 17  D22
             D23 15 │●               ●│ 16  D21 ← Eye Right
                     └─────────────────┘
                              │
                    D16 ← Teeth │ D17 ← Eye Left
                              │
```

### Connexions WS2812E

**GPIOs utilisés :**
- **GPIO16** : Teeth (18 LEDs)
- **GPIO17** : Eye Left (9 LEDs)
- **GPIO21** : Eye Right (9 LEDs)

### Schéma de connexion LEDs

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   WS2812E       │    │   WS2812E       │    │   WS2812E       │
│   TEETH (18)    │    │  EYE_LEFT (9)   │    │  EYE_RIGHT (9)  │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ VCC → 5V        │    │ VCC → 5V        │    │ VCC → 5V        │
│ GND → GND       │    │ GND → GND       │    │ GND → GND       │
│ DIN → GPIO16    │    │ DIN → GPIO17    │    │ DIN → GPIO21    │
│     + R330Ω     │    │     + R330Ω     │    │     + R330Ω     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │     ESP32       │
                    │ GPIO16,17,21    │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Alimentation    │
                    │ 5V/5A + C1000µF │
                    │ Fusible 2.5-3A  │
                    └─────────────────┘
```

### Détail des connexions LEDs

| Segment | Quantité | ESP32 GPIO | Résistance | Consommation Max |
|---------|----------|------------|------------|------------------|
| Teeth   | 18 LEDs  | GPIO16     | 330Ω       | 1.08A (18×60mA)  |
| Eye Left| 9 LEDs   | GPIO17     | 330Ω       | 0.54A (9×60mA)   |
| Eye Right| 9 LEDs  | GPIO21     | 330Ω       | 0.54A (9×60mA)   |
| **Total**| **36 LEDs**| **-**    | **-**      | **2.16A**        |

**Composants de protection :**
- **Résistances 330Ω** : Protection des lignes de données (placées près des LEDs)
- **Condensateur 1000µF** : Stabilisation de l'alimentation 5V
- **Fusible 2.5-3A** : Protection contre les surintensités

## 5. Alimentation générale

### Répartition des consommations

| Composant | Tension | Consommation | Notes |
|-----------|---------|--------------|-------|
| Raspberry Pi 5 | 5V | 3A max | Via USB-C PD |
| ESP32 | 3.3V/5V | 0.5A | Via USB ou externe |
| INMP441 ×2 | 3.3V | 10mA | Négligeable |
| MAX98357A ×2 | 5V | 1.3A max | 2×650mA à pleine puissance |
| WS2812E ×36 | 5V | 2.16A max | À pleine luminosité |
| **Total 5V** | **5V** | **≈7A** | **Alimentation externe requise** |

### Recommandations alimentation

1. **Raspberry Pi 5** : Alimentation USB-C PD 5V/3A dédiée
2. **Audio + LEDs** : Alimentation 5V/8A avec fusible 3A pour les LEDs
3. **ESP32** : Alimenté par USB ou 5V→3.3V régulateur

## 6. Plan B - Audio USB

En cas de problème avec l'I²S full-duplex :

```
┌─────────────────┐    ┌─────────────────┐
│   INMP441 ×2    │    │   DAC USB       │
│   (I²S Input)   │    │   + Ampli       │
├─────────────────┤    ├─────────────────┤
│ Vers GPIO20     │    │ USB → RPi5      │
│ (Entrée OK)     │    │ Sortie → HP     │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────────────────┘
                   │
         ┌─────────────────┐
         │ Raspberry Pi 5  │
         │ I²S In + USB Out│
         └─────────────────┘
```

**Avantages :**
- Conserve l'entrée I²S (microphones)
- Sortie audio via DAC USB fiable
- Ne bloque pas le planning

## 7. Validation du câblage

### Tests à effectuer

1. **Continuité** : Vérifier toutes les connexions avec multimètre
2. **Alimentation** : Mesurer les tensions 3.3V et 5V
3. **I²S Audio** : Test d'enregistrement et lecture
4. **LEDs** : Test de chaque segment individuellement
5. **Communication** : MQTT entre tous les composants

### Métriques cibles

- **Latence audio** : <100ms (enregistrement → lecture)
- **Synchronisation LEDs** : <60ms avec l'audio
- **Consommation** : <7A total à pleine charge
- **Température** : <70°C pour tous les composants

---

**Références :**
- Dossier de définition Bender v1.2
- Documentation Adafruit I²S
- Spécifications ESP32 et WS2812E