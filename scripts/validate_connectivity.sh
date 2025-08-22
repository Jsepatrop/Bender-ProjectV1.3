#!/bin/bash
# Script de validation connectivité - Assistant Vocal Bender v1.2
# Teste les accès aux machines avant déploiement
# Usage: ./scripts/validate_connectivity.sh

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

ENV_FILE="${1:-.env.local}"

echo -e "${BLUE}=== VALIDATION CONNECTIVITÉ BENDER v1.2 ===${NC}"
echo

# Chargement configuration
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}❌ Fichier $ENV_FILE introuvable${NC}"
    echo -e "${YELLOW}   Copier .env.sample vers .env.local et remplir les valeurs${NC}"
    exit 1
fi

# Parse .env.local
declare -A config
while IFS='=' read -r key value; do
    # Ignorer commentaires et lignes vides
    [[ $key =~ ^[[:space:]]*# ]] && continue
    [[ -z $key ]] && continue
    # Supprimer espaces et quotes
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs | sed 's/^["\x27]\|["\x27]$//g')
    config["$key"]="$value"
done < "$ENV_FILE"

echo -e "${GREEN}📋 Configuration chargée depuis $ENV_FILE${NC}"
echo

# === TEST 1: RASPBERRY PI 5 ===
echo -e "${BLUE}🔍 TEST 1: Raspberry Pi 5${NC}"
PI5_HOST="${config[PI5_HOST]}"
PI5_USER="${config[PI5_USER]}"

if [[ -z "$PI5_HOST" ]]; then
    echo -e "${RED}❌ PI5_HOST non défini dans $ENV_FILE${NC}"
else
    # Test ping
    echo -n "   Ping $PI5_HOST..."
    if ping -c 2 -W 3 "$PI5_HOST" >/dev/null 2>&1; then
        echo -e " ${GREEN}✅ OK${NC}"
        
        # Test SSH
        SSH_KEY="${config[PI5_KEY_PATH]}"
        SSH_KEY="${SSH_KEY/#\~/$HOME}"  # Remplacer ~ par $HOME
        
        if [[ -n "$SSH_KEY" && -f "$SSH_KEY" ]]; then
            echo -n "   SSH avec clé..."
            if ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o BatchMode=yes "$PI5_USER@$PI5_HOST" "echo 'SSH OK'" >/dev/null 2>&1; then
                echo -e " ${GREEN}✅ OK${NC}"
            else
                echo -e " ${RED}❌ ÉCHEC${NC}"
                echo -e "${YELLOW}      Vérifier clé SSH et autorisation${NC}"
            fi
        else
            echo -e "${YELLOW}   SSH: Clé non trouvée, test avec mot de passe requis${NC}"
        fi
    else
        echo -e " ${RED}❌ ÉCHEC${NC}"
        echo -e "${YELLOW}      Vérifier IP et réseau${NC}"
    fi
fi
echo

# === TEST 2: DELL T630 ===
echo -e "${BLUE}🔍 TEST 2: Dell T630${NC}"
T630_HOST="${config[T630_HOST]}"

if [[ -z "$T630_HOST" ]]; then
    echo -e "${RED}❌ T630_HOST non défini dans $ENV_FILE${NC}"
else
    # Test ping
    echo -n "   Ping $T630_HOST..."
    if ping -c 2 -W 3 "$T630_HOST" >/dev/null 2>&1; then
        echo -e " ${GREEN}✅ OK${NC}"
        echo -e "${YELLOW}   WinRM: Test depuis Linux non implémenté${NC}"
        echo -e "${YELLOW}   Utiliser validate_connectivity.ps1 sur Windows${NC}"
    else
        echo -e " ${RED}❌ ÉCHEC${NC}"
        echo -e "${YELLOW}      Vérifier IP et réseau${NC}"
    fi
fi
echo

# === TEST 3: HOME ASSISTANT ===
echo -e "${BLUE}🔍 TEST 3: Home Assistant${NC}"
HA_URL="${config[HA_URL]}"
HA_TOKEN="${config[HA_TOKEN]}"

if [[ -z "$HA_URL" ]]; then
    echo -e "${RED}❌ HA_URL non défini dans $ENV_FILE${NC}"
else
    echo -n "   API $HA_URL..."
    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s -w "%{http_code}" -H "Authorization: Bearer $HA_TOKEN" \
                       -H "Content-Type: application/json" \
                       --connect-timeout 10 \
                       "$HA_URL/api/" 2>/dev/null || echo "000")
        
        http_code="${response: -3}"
        if [[ "$http_code" == "200" ]]; then
            echo -e " ${GREEN}✅ OK${NC}"
        else
            echo -e " ${RED}❌ ÉCHEC (HTTP $http_code)${NC}"
            echo -e "${YELLOW}      Vérifier URL et token${NC}"
        fi
    else
        echo -e " ${YELLOW}❌ curl non disponible${NC}"
    fi
fi
echo

# === TEST 4: MQTT BROKER ===
echo -e "${BLUE}🔍 TEST 4: MQTT Broker${NC}"
MQTT_HOST="${config[MQTT_HOST]}"
MQTT_PORT="${config[MQTT_PORT_PLAIN]:-1883}"

if [[ -z "$MQTT_HOST" ]]; then
    echo -e "${RED}❌ MQTT_HOST non défini dans $ENV_FILE${NC}"
else
    echo -n "   Port TCP $MQTT_HOST:$MQTT_PORT..."
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w5 "$MQTT_HOST" "$MQTT_PORT" 2>/dev/null; then
            echo -e " ${GREEN}✅ OK${NC}"
        else
            echo -e " ${RED}❌ ÉCHEC${NC}"
            echo -e "${YELLOW}      Vérifier broker MQTT et port${NC}"
        fi
    elif command -v telnet >/dev/null 2>&1; then
        if timeout 5 telnet "$MQTT_HOST" "$MQTT_PORT" </dev/null >/dev/null 2>&1; then
            echo -e " ${GREEN}✅ OK${NC}"
        else
            echo -e " ${RED}❌ ÉCHEC${NC}"
            echo -e "${YELLOW}      Vérifier broker MQTT et port${NC}"
        fi
    else
        echo -e " ${YELLOW}❌ nc/telnet non disponible${NC}"
    fi
fi
echo

# === TEST 5: ESP32 PORT SÉRIE ===
echo -e "${BLUE}🔍 TEST 5: ESP32 Port Série${NC}"
ESP32_PORT="${config[ESP32_PORT]}"

if [[ -z "$ESP32_PORT" ]]; then
    echo -e "${RED}❌ ESP32_PORT non défini dans $ENV_FILE${NC}"
else
    # Convertir port Windows vers Linux si nécessaire
    if [[ "$ESP32_PORT" =~ ^COM[0-9]+$ ]]; then
        echo -e "${YELLOW}   Port Windows $ESP32_PORT détecté${NC}"
        echo -e "${YELLOW}   Ports série Linux disponibles:${NC}"
        ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | head -5 || echo -e "${YELLOW}      Aucun port série trouvé${NC}"
    else
        echo -n "   Port $ESP32_PORT..."
        if [[ -e "$ESP32_PORT" ]]; then
            echo -e " ${GREEN}✅ OK${NC}"
        else
            echo -e " ${RED}❌ ÉCHEC${NC}"
            echo -e "${YELLOW}      Vérifier connexion USB ESP32${NC}"
            echo -e "${YELLOW}      Ports disponibles:${NC}"
            ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | head -5 || echo -e "${YELLOW}        Aucun port série trouvé${NC}"
        fi
    fi
fi
echo

echo -e "${BLUE}=== VALIDATION TERMINÉE ===${NC}"
echo -e "${YELLOW}Vérifier les échecs avant de continuer le déploiement${NC}"