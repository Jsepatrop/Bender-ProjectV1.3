# PRÉREQUIS - Assistant Vocal « Bender » v1.2

## Informations manquantes critiques

### Accès machines

#### Dell T630 (Windows Server 2022)
**Requis pour** : Installation Docker/WSL2, containers ASR/LLM/TTS  
**Informations nécessaires** :
- [X] **IP/Hostname** : `192.168.1.100`
- [X] **Port WinRM/SSH** : `5985/22` (défaut 5985/22)
- [X] **Utilisateur admin** : `Plex`
- [X] **Méthode d'authentification** : 
  - [X] Mot de passe (à fournir via .env.local : `Bibi14170!`)
  - [ ] Certificat/clé (chemin : `_______________`)
  - [ ] Kerberos/domaine
- [X] **GPU présent** : Oui/Non → `OUI`
  - Si oui, modèle : `DUAL-GTX1070-O8G`
  - Drivers installés : Oui/Non
- [X] **RAM totale** : `160` GB
- [X] **Espace disque libre** : `160` GB

#### Raspberry Pi 5
**Requis pour** : Services audio, UI, router intents  
**Informations nécessaires** :
- [X] **IP/Hostname** : `192.168.1.104`
- [X] **Port SSH** : `22` (défaut 22)
- [X] **Utilisateur** : `bender` (défaut pi)
- [X] **Méthode d'authentification** : 
  - [x] Clé SSH (chemin : `~/.ssh/id_ed25519.pub`)
  - [X] Mot de passe (à éviter)
- [X] **OS installé** : Raspberry Pi OS Lite (64-bit)
- [X] **Carte SD** : ≥ 64 GB classe 10

#### ESP32
**Requis pour** : Firmware LEDs  
**Informations nécessaires** :
- [X] **Modèle exact** : autre : `APKLVSR ESP-32S`
- [X] **Port série** : `COM3` (Windows)
- [X] **Accès physique** : Disponible pour flash firmware

---

### Home Assistant & MQTT

#### Home Assistant
**Requis pour** : Intégration domotique, métriques  
**Informations nécessaires** :
- [X] **URL HA** : `https://alban.freeboxos.fr:8123`
- [X] **Token d'accès long terme** : `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIwYmQ0NmNkMjcxODk0NzBjODgzMmVjMDI3OThkYWJjNyIsImlhdCI6MTc1NTg2ODAwMCwiZXhwIjoyMDcxMjI4MDAwfQ.O5O5BHWgeG9fqu6ioflMwoIQkxceJHOTari78-R7zac` (à mettre dans .env.local)
- [X] **Version HA** : `2025.8.3` (≥ 2023.x recommandé)
- [X] **MQTT intégration** : Activée Oui

#### Mosquitto MQTT
**Requis pour** : Communication inter-services  
**Informations nécessaires** :
- [X] **Broker hébergé sur** : 
  - [X] Home Assistant (addon)
  - [ ] Machine dédiée : IP `_______________`
  - [ ] Pi5 (à installer)
- [X] **Host** : `192.168.1.138`
- [X] **Port MQTT** : `1883` (défaut 1883 non-TLS, 8883 TLS)
- [X] **TLS requis** : Oui/Non → `Non` (pour l'instant)
  - Si oui, **CA existante** : Oui
  - Chemin certificats : `C:\ssl`
- [X] **Utilisateur** : `mqttuser`
- [X] **Mot de passe** : `Bibi14170!`
- [X] **Utilisateurs techniques requis** :
  - `bender-pi` (Pi5 services)
  - `bender-esp32` (ESP32 firmware)
  - `bender-t630` (containers T630)
  - Mots de passe à générer automatiquement

---

### Matériel audio

#### Microphones INMP441
**Requis pour** : Capture audio stéréo  
**Statut** :
- [X] **2× INMP441 disponibles** : Oui
- [X] **Câblage prévu** : 
  - Front (L/R=GND) + Torse (L/R=3V3)
  - Bus I²S partagé vers Pi5

**Pinout INMP441 :**
- VDD → 3.3V (RPi5 pin 1 ou 17)
- GND → GND (RPi5 pin 6, 9, 14, 20, 25, 30, 34, 39)
- L/R → GND (front/gauche) ou 3.3V (torse/droite)
- WS (LRCLK) → GPIO19 (RPi5 pin 35)
- SCK (BCLK) → GPIO18 (RPi5 pin 12)
- SD (DIN) → GPIO20 (RPi5 pin 38) - **bus partagé entre les 2 micros**

#### Amplificateurs MAX98357A
**Requis pour** : Sortie audio vers haut-parleurs  
**Statut** :
- [X] **2× MAX98357A disponibles** : Oui/Non
- [X] **Haut-parleurs 4Ω disponibles** : Oui
- [X] **Alimentation 5V suffisante** : Oui (≥2A recommandé, jusqu'à 3W par ampli)

**Pinout MAX98357A :**
- Vin → 5V (alimentation externe recommandée)
- GND → GND commun
- LRC → GPIO19 (RPi5 pin 35) - **bus partagé**
- BCLK → GPIO18 (RPi5 pin 12) - **bus partagé**
- DIN → GPIO21 (RPi5 pin 40) - **bus partagé entre les 2 amplis**
- GAIN → Non connecté (9dB par défaut) ou ajustable
- SD → Vin (canal stéréo mixé) ou résistance pour L/R séparé

#### Plan B : DAC USB
**Si I²S full-duplex pose problème**  
**Informations** :
- [ ] **DAC USB disponible** : Modèle `_______________`
- [ ] **Amplificateur externe** : Modèle `_______________`
- [ ] **Acceptation Plan B** : Oui/Non (garde mics I²S, sortie USB)

---

### LEDs WS2812E

#### Chaînes LEDs
**Requis pour** : Effets visuels synchronisés  
**Statut** :
- [X] **LEDs teeth (18×)** : Disponibles Oui
- [X] **LEDs eye_left (9×)** : Disponibles Oui
- [X] **LEDs eye_right (9×)** : Disponibles Oui
- [X] **Résistances 330Ω (×3)** : Disponibles Oui
- [X] **Condensateur 1000µF** : Disponible Non

**Pinout WS2812E vers ESP32 :**
- VCC → 5V (alimentation externe)
- GND → GND commun ESP32 + alimentation
- DIN (Teeth) → GPIO16 + résistance 330Ω
- DIN (Eye Left) → GPIO17 + résistance 330Ω
- DIN (Eye Right) → GPIO21 + résistance 330Ω

**Notes importantes :**
- Chaque LED consomme ~60mA à pleine luminosité (20mA/couleur)
- Total théorique : 36 LEDs × 60mA = 2.16A
- Résistances 330Ω placées près des LEDs pour protection
- Condensateur 1000µF pour stabiliser l'alimentation

#### Alimentation LEDs
**Critique pour stabilité**  
**Informations** :
- [X] **Alim 5V/5A disponible** : Oui
- [X] **Fusible 2.5-3A** : Disponible Oui
- [X] **Câblage GND commun** : Prévu Oui

---

### Voix TTS par défaut

#### Voix Piper FR officielle
**Requis v1** : Voix reproductible avec checksum  
**Choix proposés** (à valider) :

1. **fr_FR-upmc-medium** (recommandé)
   - Qualité : Bonne, naturelle
   - Taille : ~50 MB
   - Vitesse : Rapide
   - **Acceptation** : Oui/Non → `Non`

2. **fr_FR-siwis-medium**
   - Qualité : Très bonne
   - Taille : ~80 MB
   - Vitesse : Moyenne
   - **Acceptation** : Oui/Non → `Oui`

**Validation requise** :
- [ ] **Écoute échantillons** : Lien fourni pour tests
- [ ] **Choix final** : `_______________`
- [ ] **Version pinnée** : Sera enregistrée comme `fr-default@X.Y.Z`

---

### Réseau et sécurité

#### Connectivité
**Requis pour** : Communication inter-machines  
**Informations** :
- [X] **Réseau local** : Plage IP `192.168.1.0/24` (ex: 192.168.1.0/24)
- [ ] **Latence Pi↔T630** : < 10 ms (à vérifier)
- [ ] **Bande passante** : ≥ 100 Mbps recommandé
- [ ] **Firewall/restrictions** : Ports à ouvrir `_______________`

#### Certificats TLS
**Requis pour** : HTTPS UI + MQTTS  
**Approche** :
- [ ] **CA locale auto-générée** : Acceptée (recommandé)
- [X] **Certificats existants** : Chemin `C:\ssl`
- [ ] **Domaines/IPs** : À inclure dans certificats
  - Pi5 : `bender-pi.local` ou IP
  - T630 : `bender-t630.local` ou IP

---

### Développement et déploiement

#### Outils requis
**Sur machine de développement**  
**Statut** :
- [ ] **Git** : Installé Oui/Non
- [ ] **Docker** : Installé Oui/Non (pour tests locaux)
- [ ] **Node.js** : Version `_______________` (≥16 requis pour UI)
- [ ] **Python** : Version `_______________` (≥3.9 requis)
- [ ] **PlatformIO** : Pour firmware ESP32, installé Oui/Non

#### Accès Internet
**Requis pour** : Téléchargement dépendances  
**Informations** :
- [X] **Accès direct** : Oui
- [ ] **Proxy** : URL `_______________`
- [ ] **Restrictions** : Domaines bloqués `_______________`

---

## Actions de validation

### Tests préliminaires
**Avant démarrage phase 1**  

1. **Connectivité machines** :
   ```bash
   # Test accès T630
   ping <IP_T630>
   # Test WinRM/SSH
   
   # Test accès Pi5
   ping <IP_PI5>
   ssh <user>@<IP_PI5>
   ```

2. **Test MQTT** :
   ```bash
   # Test connexion broker
   mosquitto_pub -h <BROKER_IP> -t test -m "hello"
   mosquitto_sub -h <BROKER_IP> -t test
   ```

3. **Test HA API** :
   ```bash
   curl -H "Authorization: Bearer <TOKEN>" \
        http://<HA_IP>:8123/api/states
   ```

### Validation matériel
**Avant phase 1 (maquette)**  

- [X] **Inventaire complet** : Tous composants listés disponibles
- [X] **Outils nécessaires** : Fer à souder, multimètre, breadboard
- [X] **Espace de travail** : Table, éclairage, ventilation

---

## Fichiers de configuration

### À créer après validation

#### `.env.local` (NON versionné)
```bash
# Accès machines
T630_HOST=<IP_T630>
T630_USER=<USER>
T630_PASS=<PASSWORD>

PI5_HOST=<IP_PI5>
PI5_USER=<USER>
PI5_KEY_PATH=<SSH_KEY>

# Home Assistant
HA_URL=<URL>
HA_TOKEN=<TOKEN>

# MQTT
MQTT_HOST=<BROKER_IP>
MQTT_USER_PI=<USER>
MQTT_PASS_PI=<PASSWORD>
MQTT_USER_ESP32=<USER>
MQTT_PASS_ESP32=<PASSWORD>
MQTT_USER_T630=<USER>
MQTT_PASS_T630=<PASSWORD>
```

#### `inventory.yml` (Ansible)
```yaml
all:
  children:
    t630:
      hosts:
        bender-t630:
          ansible_host: <IP_T630>
          ansible_user: <USER>
          ansible_connection: winrm
    pi5:
      hosts:
        bender-pi:
          ansible_host: <IP_PI5>
          ansible_user: <USER>
          ansible_ssh_private_key_file: <KEY_PATH>
```

---

## Validation finale

**Critères pour démarrer phase 1** :
- [ ] Tous les champs `_______________` remplis
- [ ] Tests connectivité réussis
- [ ] Matériel inventorié et disponible
- [ ] Fichiers .env.local créés
- [ ] Choix voix TTS validé
- [ ] Plan B audio accepté si nécessaire

**Responsable validation** : Chef de projet  
**Date limite** : Avant démarrage EPIC 1  
**Mise à jour** : Ce fichier sera mis à jour au fur et à mesure