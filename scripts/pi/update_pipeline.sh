#!/bin/bash
# Script de mise à jour du pipeline audio sur le Pi
# À exécuter directement sur le Raspberry Pi

echo "=== Mise à jour Pipeline Audio Bender ==="

# Arrêt du service
echo "Arrêt du service bender-audio..."
sudo systemctl stop bender-audio.service

# Sauvegarde de l'ancien fichier
echo "Sauvegarde de l'ancien pipeline..."
sudo cp /opt/bender/audio_pipeline.py /opt/bender/audio_pipeline.py.bak

# Mise à jour du pipeline avec mode test MQTT
echo "Mise à jour du pipeline audio..."
sudo tee /opt/bender/audio_pipeline.py > /dev/null << 'EOF'
#!/usr/bin/env python3
"""
Bender Audio Pipeline - Raspberry Pi 5
Pipeline audio temps réel : Capture → AEC → VAD → Conversion → MQTT

Référence : Section 4.2.1 du Dossier de définition
Auteur : Assistant Bender DevOps
Version : 1.0 (Mode test sans MQTT)
"""

import asyncio
import logging
import json
import time
from typing import Optional, Callable
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import sounddevice as sd
import webrtcvad
import librosa
# import paho.mqtt.client as mqtt  # Désactivé pour test
from scipy import signal

# Configuration
@dataclass
class AudioConfig:
    """Configuration pipeline audio"""
    # Paramètres I²S
    device_name: str = "hw:0,0"  # Google VoiceHAT
    sample_rate_in: int = 48000   # Fréquence native I²S
    sample_rate_out: int = 16000  # Fréquence ASR
    channels: int = 2             # Stéréo INMP441
    dtype: str = "int32"          # Format S32_LE
    
    # Paramètres traitement
    chunk_size: int = 1024        # Taille buffer (21ms @ 48kHz)
    vad_aggressiveness: int = 2   # VAD 0-3 (2=équilibré)
    aec_enabled: bool = True      # AEC WebRTC
    
    # Paramètres EQ/Limiter
    eq_enabled: bool = True
    limiter_enabled: bool = True
    limiter_threshold: float = 0.8
    
    # MQTT (désactivé pour test)
    mqtt_enabled: bool = False
    mqtt_broker: str = "192.168.1.138"
    mqtt_port: int = 1883
    mqtt_topic_partial: str = "bender/asr/partial"
    mqtt_topic_final: str = "bender/asr/final"
    mqtt_topic_metrics: str = "bender/sys/metrics"

class AudioPipeline:
    """Pipeline audio temps réel pour Bender"""
    
    def __init__(self, config_path: str = "/opt/bender/audio_config.json"):
        self.config = self._load_config(config_path)
        self.logger = self._setup_logging()
        
        # État du pipeline
        self.is_running = False
        self.mqtt_enabled = self.config.mqtt_enabled
        
        # Composants audio
        self.vad = webrtcvad.Vad(self.config.vad_aggressiveness)
        self.audio_stream = None
        
        # Métriques
        self.metrics = {
            "chunks_processed": 0,
            "voice_detected": 0,
            "avg_latency_ms": 0.0,
            "last_update": time.time()
        }
        
        self.logger.info(f"Pipeline initialisé - MQTT: {'activé' if self.mqtt_enabled else 'désactivé'}")
    
    def _load_config(self, config_path: str) -> AudioConfig:
        """Charger la configuration depuis JSON"""
        try:
            with open(config_path, 'r') as f:
                config_data = json.load(f)
            return AudioConfig(**config_data)
        except FileNotFoundError:
            logging.warning(f"Config non trouvée: {config_path}, utilisation des défauts")
            return AudioConfig()
        except Exception as e:
            logging.error(f"Erreur chargement config: {e}")
            return AudioConfig()
    
    def _setup_logging(self) -> logging.Logger:
        """Configuration du logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.StreamHandler(),
                logging.FileHandler('/var/log/bender-audio.log')
            ]
        )
        return logging.getLogger('BenderAudio')
    
    def _audio_callback(self, indata, frames, time_info, status):
        """Callback traitement audio temps réel"""
        if status:
            self.logger.warning(f"Status audio: {status}")
        
        try:
            start_time = time.time()
            
            # Conversion en mono (moyenne des canaux)
            audio_mono = np.mean(indata, axis=1)
            
            # Normalisation
            audio_normalized = audio_mono / np.max(np.abs(audio_mono)) if np.max(np.abs(audio_mono)) > 0 else audio_mono
            
            # VAD sur chunk 16kHz
            audio_16k = librosa.resample(audio_normalized.astype(np.float32), 
                                       orig_sr=self.config.sample_rate_in, 
                                       target_sr=self.config.sample_rate_out)
            
            # Conversion pour VAD (16-bit PCM)
            audio_vad = (audio_16k * 32767).astype(np.int16)
            
            # Détection de voix
            is_speech = self.vad.is_speech(audio_vad.tobytes(), self.config.sample_rate_out)
            
            # Mise à jour métriques
            self.metrics["chunks_processed"] += 1
            if is_speech:
                self.metrics["voice_detected"] += 1
            
            latency = (time.time() - start_time) * 1000
            self.metrics["avg_latency_ms"] = (self.metrics["avg_latency_ms"] * 0.9) + (latency * 0.1)
            
            # Log périodique
            if self.metrics["chunks_processed"] % 100 == 0:
                self.logger.info(f"Chunks: {self.metrics['chunks_processed']}, "
                               f"Voix: {self.metrics['voice_detected']}, "
                               f"Latence: {self.metrics['avg_latency_ms']:.1f}ms")
            
        except Exception as e:
            self.logger.error(f"Erreur callback audio: {e}")
    
    async def start(self):
        """Démarrer le pipeline audio"""
        try:
            self.logger.info("Démarrage du pipeline audio...")
            
            # Configuration du stream audio
            self.audio_stream = sd.InputStream(
                device=self.config.device_name,
                samplerate=self.config.sample_rate_in,
                channels=self.config.channels,
                dtype=self.config.dtype,
                blocksize=self.config.chunk_size,
                callback=self._audio_callback
            )
            
            self.audio_stream.start()
            self.is_running = True
            
            self.logger.info(f"Pipeline démarré - Device: {self.config.device_name}, "
                           f"SR: {self.config.sample_rate_in}Hz, "
                           f"Channels: {self.config.channels}")
            
            # Boucle principale
            while self.is_running:
                await asyncio.sleep(1)
                
        except Exception as e:
            self.logger.error(f"Erreur démarrage pipeline: {e}")
            raise
    
    async def stop(self):
        """Arrêter le pipeline"""
        self.logger.info("Arrêt du pipeline audio...")
        self.is_running = False
        
        if self.audio_stream:
            self.audio_stream.stop()
            self.audio_stream.close()
        
        self.logger.info("Pipeline arrêté")

async def main():
    """Point d'entrée principal"""
    pipeline = AudioPipeline()
    
    try:
        await pipeline.start()
    except KeyboardInterrupt:
        print("\nArrêt demandé par l'utilisateur")
    except Exception as e:
        print(f"Erreur: {e}")
    finally:
        await pipeline.stop()

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Permissions
echo "Configuration des permissions..."
sudo chown bender:bender /opt/bender/audio_pipeline.py
sudo chmod 755 /opt/bender/audio_pipeline.py

# Redémarrage du service
echo "Redémarrage du service..."
sudo systemctl start bender-audio.service
sudo systemctl status bender-audio.service --no-pager -l

echo "=== Mise à jour terminée ==="