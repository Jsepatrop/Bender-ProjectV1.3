#!/usr/bin/env python3
"""
Router d'intents Home Assistant pour Bender
Gère la communication MQTT avec HA et le routage des commandes domotique

Auteur: Assistant Bender
Version: 1.0
Date: 2025-08-22
"""

import json
import logging
import time
import threading
from typing import Dict, Any, Optional, Callable
from dataclasses import dataclass, asdict
from datetime import datetime

import paho.mqtt.client as mqtt
import requests
from requests.auth import HTTPBasicAuth


@dataclass
class HAConfig:
    """Configuration Home Assistant"""
    base_url: str = "http://192.168.1.138:8123"
    token: str = ""  # À définir dans .env.local
    timeout: int = 5
    
@dataclass
class MQTTConfig:
    """Configuration MQTT"""
    broker: str = "192.168.1.138"
    port: int = 1883
    username: str = "bender"
    password: str = ""  # À définir dans .env.local
    client_id: str = "bender-intent-router"
    keepalive: int = 60
    
    # Topics MQTT
    topic_intent: str = "bender/intent"
    topic_asr_final: str = "bender/asr/final"
    topic_tts_say: str = "bender/tts/say"
    topic_sys_metrics: str = "bender/sys/metrics"
    topic_sys_log: str = "bender/sys/log"


class HomeAssistantClient:
    """Client pour interagir avec Home Assistant"""
    
    def __init__(self, config: HAConfig):
        self.config = config
        self.logger = logging.getLogger("bender.ha_client")
        self.session = requests.Session()
        
        if config.token:
            self.session.headers.update({
                "Authorization": f"Bearer {config.token}",
                "Content-Type": "application/json"
            })
    
    def call_service(self, domain: str, service: str, 
                    entity_id: Optional[str] = None, 
                    service_data: Optional[Dict] = None) -> bool:
        """Appel d'un service Home Assistant"""
        url = f"{self.config.base_url}/api/services/{domain}/{service}"
        
        data = {}
        if entity_id:
            data["entity_id"] = entity_id
        if service_data:
            data.update(service_data)
            
        try:
            response = self.session.post(
                url, 
                json=data, 
                timeout=self.config.timeout
            )
            response.raise_for_status()
            self.logger.info(f"Service {domain}.{service} appelé avec succès")
            return True
            
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Erreur appel service {domain}.{service}: {e}")
            return False
    
    def get_state(self, entity_id: str) -> Optional[Dict]:
        """Récupère l'état d'une entité"""
        url = f"{self.config.base_url}/api/states/{entity_id}"
        
        try:
            response = self.session.get(url, timeout=self.config.timeout)
            response.raise_for_status()
            return response.json()
            
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Erreur récupération état {entity_id}: {e}")
            return None
    
    def test_connection(self) -> bool:
        """Test de connexion à Home Assistant"""
        url = f"{self.config.base_url}/api/"
        
        try:
            response = self.session.get(url, timeout=self.config.timeout)
            response.raise_for_status()
            self.logger.info("Connexion Home Assistant OK")
            return True
            
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Erreur connexion Home Assistant: {e}")
            return False


class IntentRouter:
    """Router principal pour les intents Bender"""
    
    def __init__(self, ha_config: HAConfig, mqtt_config: MQTTConfig):
        self.ha_config = ha_config
        self.mqtt_config = mqtt_config
        self.logger = logging.getLogger("bender.intent_router")
        
        # Mode test (désactiver HA temporairement)
        self.test_mode = True
        
        # Clients
        if not self.test_mode:
            self.ha_client = HomeAssistantClient(ha_config)
        else:
            self.logger.info("Mode test: Home Assistant désactivé")
            self.ha_client = None
            
        self.mqtt_client = mqtt.Client(client_id=mqtt_config.client_id)
        
        # État
        self.connected = False
        self.running = False
        self.stats = {
            "intents_processed": 0,
            "ha_commands_sent": 0,
            "errors": 0,
            "start_time": None
        }
        
        # Configuration MQTT
        self.setup_mqtt()
        
        # Mapping des intents
        self.intent_handlers = {
            "turn_on_light": self.handle_light_on,
            "turn_off_light": self.handle_light_off,
            "set_brightness": self.handle_brightness,
            "get_temperature": self.handle_get_temperature,
            "get_status": self.handle_get_status,
            "play_music": self.handle_play_music,
            "stop_music": self.handle_stop_music,
            "set_volume": self.handle_set_volume,
            "unknown": self.handle_unknown_intent
        }
    
    def setup_mqtt(self):
        """Configuration du client MQTT"""
        # Callbacks
        self.mqtt_client.on_connect = self.on_mqtt_connect
        self.mqtt_client.on_disconnect = self.on_mqtt_disconnect
        self.mqtt_client.on_message = self.on_mqtt_message
        
        # Authentification si configurée
        if self.mqtt_config.username and self.mqtt_config.password:
            self.mqtt_client.username_pw_set(
                self.mqtt_config.username, 
                self.mqtt_config.password
            )
    
    def on_mqtt_connect(self, client, userdata, flags, rc):
        """Callback connexion MQTT"""
        if rc == 0:
            self.connected = True
            self.logger.info("Connexion MQTT réussie")
            
            # Souscription aux topics
            topics = [
                (self.mqtt_config.topic_intent, 0),
                (self.mqtt_config.topic_asr_final, 0)
            ]
            
            for topic, qos in topics:
                client.subscribe(topic, qos)
                self.logger.info(f"Souscription à {topic}")
                
        else:
            self.connected = False
            self.logger.error(f"Échec connexion MQTT: code {rc}")
    
    def on_mqtt_disconnect(self, client, userdata, rc):
        """Callback déconnexion MQTT"""
        self.connected = False
        self.logger.warning(f"Déconnexion MQTT: code {rc}")
    
    def on_mqtt_message(self, client, userdata, msg):
        """Traitement des messages MQTT"""
        try:
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            
            self.logger.debug(f"Message reçu sur {topic}: {payload}")
            
            if topic == self.mqtt_config.topic_intent:
                self.process_intent(payload)
            elif topic == self.mqtt_config.topic_asr_final:
                self.process_asr_result(payload)
                
        except Exception as e:
            self.logger.error(f"Erreur traitement message MQTT: {e}")
            self.stats["errors"] += 1
    
    def process_intent(self, payload: str):
        """Traitement d'un intent reçu"""
        try:
            intent_data = json.loads(payload)
            intent_name = intent_data.get("intent", "unknown")
            entities = intent_data.get("entities", {})
            confidence = intent_data.get("confidence", 0.0)
            
            self.logger.info(f"Intent reçu: {intent_name} (conf: {confidence:.2f})")
            
            # Seuil de confiance minimum
            if confidence < 0.5:
                self.logger.warning(f"Confiance trop faible: {confidence:.2f}")
                self.send_tts_response("Je n'ai pas bien compris, pouvez-vous répéter ?")
                return
            
            # Routage vers le handler approprié
            handler = self.intent_handlers.get(intent_name, self.handle_unknown_intent)
            handler(entities, confidence)
            
            self.stats["intents_processed"] += 1
            
        except json.JSONDecodeError as e:
            self.logger.error(f"Erreur parsing JSON intent: {e}")
            self.stats["errors"] += 1
        except Exception as e:
            self.logger.error(f"Erreur traitement intent: {e}")
            self.stats["errors"] += 1
    
    def process_asr_result(self, payload: str):
        """Traitement d'un résultat ASR final"""
        try:
            asr_data = json.loads(payload)
            text = asr_data.get("text", "")
            confidence = asr_data.get("confidence", 0.0)
            
            self.logger.info(f"ASR final: '{text}' (conf: {confidence:.2f})")
            
            # Log pour debug
            self.publish_log(f"ASR: {text} ({confidence:.2f})")
            
        except json.JSONDecodeError as e:
            self.logger.error(f"Erreur parsing JSON ASR: {e}")
    
    # Handlers d'intents
    def handle_light_on(self, entities: Dict, confidence: float):
        """Allumer une lumière"""
        room = entities.get("room", "salon")
        entity_id = f"light.{room}"
        
        if self.ha_client.call_service("light", "turn_on", entity_id):
            self.send_tts_response(f"J'allume la lumière du {room}")
            self.stats["ha_commands_sent"] += 1
        else:
            self.send_tts_response(f"Impossible d'allumer la lumière du {room}")
    
    def handle_light_off(self, entities: Dict, confidence: float):
        """Éteindre une lumière"""
        room = entities.get("room", "salon")
        entity_id = f"light.{room}"
        
        if self.ha_client.call_service("light", "turn_off", entity_id):
            self.send_tts_response(f"J'éteins la lumière du {room}")
            self.stats["ha_commands_sent"] += 1
        else:
            self.send_tts_response(f"Impossible d'éteindre la lumière du {room}")
    
    def handle_brightness(self, entities: Dict, confidence: float):
        """Régler la luminosité"""
        room = entities.get("room", "salon")
        brightness = entities.get("brightness", 50)
        entity_id = f"light.{room}"
        
        # Conversion pourcentage vers valeur HA (0-255)
        brightness_value = int(brightness * 255 / 100)
        
        service_data = {"brightness": brightness_value}
        
        if self.ha_client.call_service("light", "turn_on", entity_id, service_data):
            self.send_tts_response(f"Luminosité du {room} réglée à {brightness}%")
            self.stats["ha_commands_sent"] += 1
        else:
            self.send_tts_response(f"Impossible de régler la luminosité du {room}")
    
    def handle_get_temperature(self, entities: Dict, confidence: float):
        """Obtenir la température"""
        room = entities.get("room", "salon")
        entity_id = f"sensor.temperature_{room}"
        
        state = self.ha_client.get_state(entity_id)
        if state:
            temp = state.get("state", "inconnue")
            unit = state.get("attributes", {}).get("unit_of_measurement", "°C")
            self.send_tts_response(f"La température du {room} est de {temp} {unit}")
        else:
            self.send_tts_response(f"Impossible d'obtenir la température du {room}")
    
    def handle_get_status(self, entities: Dict, confidence: float):
        """Obtenir le statut du système"""
        uptime = time.time() - (self.stats["start_time"] or time.time())
        uptime_str = f"{int(uptime // 3600)}h{int((uptime % 3600) // 60)}m"
        
        response = f"Système opérationnel depuis {uptime_str}. "
        response += f"{self.stats['intents_processed']} intents traités, "
        response += f"{self.stats['ha_commands_sent']} commandes envoyées."
        
        self.send_tts_response(response)
    
    def handle_play_music(self, entities: Dict, confidence: float):
        """Lancer la musique"""
        if self.ha_client.call_service("media_player", "media_play", "media_player.salon"):
            self.send_tts_response("Je lance la musique")
            self.stats["ha_commands_sent"] += 1
        else:
            self.send_tts_response("Impossible de lancer la musique")
    
    def handle_stop_music(self, entities: Dict, confidence: float):
        """Arrêter la musique"""
        if self.ha_client.call_service("media_player", "media_stop", "media_player.salon"):
            self.send_tts_response("J'arrête la musique")
            self.stats["ha_commands_sent"] += 1
        else:
            self.send_tts_response("Impossible d'arrêter la musique")
    
    def handle_set_volume(self, entities: Dict, confidence: float):
        """Régler le volume"""
        volume = entities.get("volume", 50)
        volume_level = volume / 100.0
        
        service_data = {"volume_level": volume_level}
        
        if self.ha_client.call_service("media_player", "volume_set", 
                                     "media_player.salon", service_data):
            self.send_tts_response(f"Volume réglé à {volume}%")
            self.stats["ha_commands_sent"] += 1
        else:
            self.send_tts_response(f"Impossible de régler le volume")
    
    def handle_unknown_intent(self, entities: Dict, confidence: float):
        """Intent non reconnu"""
        self.send_tts_response("Je ne sais pas comment faire cela")
    
    def send_tts_response(self, text: str):
        """Envoyer une réponse TTS"""
        if not self.connected:
            self.logger.warning("MQTT non connecté, impossible d'envoyer TTS")
            return
        
        tts_data = {
            "text": text,
            "timestamp": datetime.now().isoformat(),
            "source": "intent_router"
        }
        
        try:
            self.mqtt_client.publish(
                self.mqtt_config.topic_tts_say,
                json.dumps(tts_data),
                qos=0
            )
            self.logger.info(f"TTS envoyé: {text}")
            
        except Exception as e:
            self.logger.error(f"Erreur envoi TTS: {e}")
    
    def publish_metrics(self):
        """Publier les métriques système"""
        if not self.connected:
            return
        
        # Test connectivité HA (seulement si pas en mode test)
        ha_connected = False
        if not self.test_mode and self.ha_client:
            ha_connected = self.ha_client.test_connection()
        
        metrics = {
            **self.stats,
            "timestamp": datetime.now().isoformat(),
            "ha_connected": ha_connected,
            "mqtt_connected": self.connected
        }
        
        try:
            self.mqtt_client.publish(
                self.mqtt_config.topic_sys_metrics,
                json.dumps(metrics),
                qos=0
            )
            
        except Exception as e:
            self.logger.error(f"Erreur publication métriques: {e}")
    
    def publish_log(self, message: str, level: str = "info"):
        """Publier un log via MQTT"""
        if not self.connected:
            return
        
        log_data = {
            "message": message,
            "level": level,
            "timestamp": datetime.now().isoformat(),
            "component": "intent_router"
        }
        
        try:
            self.mqtt_client.publish(
                self.mqtt_config.topic_sys_log,
                json.dumps(log_data),
                qos=0
            )
            
        except Exception as e:
            self.logger.error(f"Erreur publication log: {e}")
    
    def start(self):
        """Démarrer le router"""
        self.logger.info("Démarrage du router d'intents Bender...")
        
        # Test connexion HA (seulement si pas en mode test)
        if not self.test_mode:
            if not self.ha_client.test_connection():
                self.logger.error("Impossible de se connecter à Home Assistant")
                return False
        else:
            self.logger.info("Mode test: connexion Home Assistant ignorée")
        
        # Connexion MQTT (seulement si pas en mode test)
        if not self.test_mode:
            try:
                self.mqtt_client.connect(
                    self.mqtt_config.broker,
                    self.mqtt_config.port,
                    self.mqtt_config.keepalive
                )
                
                # Démarrage de la boucle MQTT
                self.mqtt_client.loop_start()
                
                # Attente de la connexion
                timeout = 10
                while not self.connected and timeout > 0:
                    time.sleep(0.5)
                    timeout -= 0.5
                
                if not self.connected:
                    self.logger.error("Timeout connexion MQTT")
                    return False
                    
            except Exception as e:
                self.logger.error(f"Erreur démarrage: {e}")
                return False
        else:
            self.logger.info("Mode test: connexion MQTT ignorée")
            self.connected = True  # Simuler la connexion en mode test
        
        self.running = True
        self.stats["start_time"] = time.time()
        
        # Thread pour les métriques périodiques
        metrics_thread = threading.Thread(target=self.metrics_loop, daemon=True)
        metrics_thread.start()
        
        self.logger.info("Router d'intents démarré avec succès")
        return True
    
    def stop(self):
        """Arrêter le router"""
        self.logger.info("Arrêt du router d'intents...")
        
        self.running = False
        
        if self.mqtt_client:
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()
        
        self.logger.info("Router d'intents arrêté")
    
    def metrics_loop(self):
        """Boucle de publication des métriques"""
        while self.running:
            try:
                self.publish_metrics()
                time.sleep(30)  # Métriques toutes les 30s
            except Exception as e:
                self.logger.error(f"Erreur boucle métriques: {e}")
                time.sleep(5)


def main():
    """Point d'entrée principal"""
    # Configuration du logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler('/opt/bender/logs/intent_router.log')
        ]
    )
    
    logger = logging.getLogger("bender.intent_router")
    
    # Configuration (à terme depuis .env.local)
    ha_config = HAConfig(
        base_url="http://192.168.1.138:8123",
        token=""  # À configurer
    )
    
    mqtt_config = MQTTConfig(
        broker="192.168.1.138",
        username="bender",
        password=""  # À configurer
    )
    
    # Création et démarrage du router
    router = IntentRouter(ha_config, mqtt_config)
    
    try:
        if router.start():
            logger.info("Router d'intents opérationnel")
            
            # Boucle principale
            while router.running:
                time.sleep(1)
        else:
            logger.error("Échec démarrage du router")
            
    except KeyboardInterrupt:
        logger.info("Interruption utilisateur")
    except Exception as e:
        logger.error(f"Erreur fatale: {e}")
    finally:
        router.stop()


if __name__ == "__main__":
    main()