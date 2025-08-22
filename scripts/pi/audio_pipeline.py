#!/usr/bin/env python3
"""
Bender Audio Pipeline - Raspberry Pi 5
Pipeline audio temps réel : Capture → AEC → VAD → Conversion → MQTT

Référence : Section 4.2.1 du Dossier de définition
Auteur : Assistant Bender DevOps
Version : 1.0
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
import paho.mqtt.client as mqtt
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
    
    # MQTT
    mqtt_broker: str = "192.168.1.138"
    mqtt_port: int = 1883
    mqtt_topic_partial: str = "bender/asr/partial"
    mqtt_topic_final: str = "bender/asr/final"
    mqtt_topic_metrics: str = "bender/sys/metrics"

class AudioPipeline:
    """Pipeline audio temps réel Bender"""
    
    def __init__(self, config: AudioConfig):
        self.config = config
        self.logger = self._setup_logging()
        
        # État pipeline
        self.is_running = False
        self.audio_buffer = np.array([], dtype=np.int32)
        self.vad = webrtcvad.Vad(config.vad_aggressiveness)
        
        # Métriques
        self.metrics = {
            "chunks_processed": 0,
            "voice_detected": 0,
            "avg_latency_ms": 0.0,
            "last_update": time.time()
        }
        
        # MQTT
        self.mqtt_client = None
        self._setup_mqtt()
        
        # Filtres audio
        self._setup_audio_filters()
        
    def _setup_logging(self) -> logging.Logger:
        """Configuration logging"""
        logger = logging.getLogger("bender.audio")
        logger.setLevel(logging.INFO)
        
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            
        return logger
        
    def _setup_mqtt(self):
        """Configuration client MQTT"""
        self.mqtt_client = mqtt.Client()
        self.mqtt_client.on_connect = self._on_mqtt_connect
        self.mqtt_client.on_disconnect = self._on_mqtt_disconnect
        # Désactiver l'authentification pour les tests initiaux
        # self.mqtt_client.username_pw_set("username", "password")
        
        # Mode test sans MQTT pour validation pipeline audio
        self.mqtt_enabled = False
        if self.mqtt_enabled:
            try:
                self.mqtt_client.connect(self.config.mqtt_broker, self.config.mqtt_port, 60)
                self.mqtt_client.loop_start()
                self.logger.info(f"MQTT connecté à {self.config.mqtt_broker}:{self.config.mqtt_port}")
            except Exception as e:
                self.logger.error(f"Erreur connexion MQTT: {e}")
        else:
            self.logger.info("Mode test: MQTT désactivé pour validation pipeline audio")
            
    def _on_mqtt_connect(self, client, userdata, flags, rc):
        """Callback connexion MQTT"""
        if rc == 0:
            self.logger.info("MQTT connecté avec succès")
        else:
            self.logger.error(f"Échec connexion MQTT: {rc}")
            
    def _on_mqtt_disconnect(self, client, userdata, rc):
        """Callback déconnexion MQTT"""
        self.logger.warning(f"MQTT déconnecté: {rc}")
        
    def _setup_audio_filters(self):
        """Configuration filtres audio (EQ, limiter)"""
        # Filtre passe-haut pour éliminer bruit basse fréquence
        nyquist = self.config.sample_rate_in // 2
        self.highpass_sos = signal.butter(
            4, 80 / nyquist, btype='high', output='sos'
        )
        
        # Filtre anti-aliasing pour downsampling
        self.antialias_sos = signal.butter(
            6, (self.config.sample_rate_out // 2) / nyquist, 
            btype='low', output='sos'
        )
        
        self.logger.info("Filtres audio configurés")
        
    def _apply_eq_limiter(self, audio_data: np.ndarray) -> np.ndarray:
        """Application EQ et limiter"""
        if not self.config.eq_enabled and not self.config.limiter_enabled:
            return audio_data
            
        # Conversion en float pour traitement
        audio_float = audio_data.astype(np.float32) / (2**31)
        
        # EQ : filtre passe-haut
        if self.config.eq_enabled:
            audio_float = signal.sosfilt(self.highpass_sos, audio_float, axis=0)
            
        # Limiter simple
        if self.config.limiter_enabled:
            audio_float = np.clip(
                audio_float, 
                -self.config.limiter_threshold, 
                self.config.limiter_threshold
            )
            
        # Retour en int32
        return (audio_float * (2**31)).astype(np.int32)
        
    def _downsample_audio(self, audio_data: np.ndarray) -> np.ndarray:
        """Conversion 48kHz → 16kHz avec anti-aliasing"""
        # Anti-aliasing
        audio_filtered = signal.sosfilt(self.antialias_sos, audio_data, axis=0)
        
        # Downsampling par facteur 3 (48000/16000)
        audio_16k = audio_filtered[::3]
        
        return audio_16k.astype(np.int16)  # VAD nécessite int16
        
    def _detect_voice(self, audio_chunk: np.ndarray) -> bool:
        """Détection activité vocale avec WebRTC VAD"""
        try:
            # VAD nécessite 10ms, 20ms ou 30ms à 16kHz
            # 1024 samples @ 48kHz = 21.33ms → 341 samples @ 16kHz ≈ 20ms
            chunk_16k = self._downsample_audio(audio_chunk)
            
            # Mono pour VAD (moyenne des canaux)
            if chunk_16k.ndim > 1:
                chunk_mono = np.mean(chunk_16k, axis=1).astype(np.int16)
            else:
                chunk_mono = chunk_16k
                
            # Ajuster à 320 samples (20ms @ 16kHz)
            if len(chunk_mono) > 320:
                chunk_mono = chunk_mono[:320]
            elif len(chunk_mono) < 320:
                chunk_mono = np.pad(chunk_mono, (0, 320 - len(chunk_mono)))
                
            # VAD
            return self.vad.is_speech(chunk_mono.tobytes(), 16000)
            
        except Exception as e:
            self.logger.error(f"Erreur VAD: {e}")
            return False
            
    def _publish_metrics(self):
        """Publication métriques MQTT"""
        self.metrics["last_update"] = time.time()
        
        if self.mqtt_enabled and self.mqtt_client and self.mqtt_client.is_connected():
            try:
                payload = json.dumps(self.metrics)
                self.mqtt_client.publish(self.config.mqtt_topic_metrics, payload)
            except Exception as e:
                self.logger.error(f"Erreur publication métriques: {e}")
        else:
            self.logger.debug(f"Métriques: {self.metrics['chunks_processed']} chunks, {self.metrics['voice_detected']} voix, {self.metrics['avg_latency_ms']:.1f}ms latence")
                
    def _audio_callback(self, indata, frames, time_info, status):
        """Callback capture audio temps réel"""
        if status:
            self.logger.warning(f"Status audio: {status}")
            
        start_time = time.time()
        
        try:
            # Application filtres
            audio_processed = self._apply_eq_limiter(indata.copy())
            
            # Détection voix
            voice_detected = self._detect_voice(audio_processed)
            
            # Mise à jour métriques
            self.metrics["chunks_processed"] += 1
            if voice_detected:
                self.metrics["voice_detected"] += 1
                
            # Calcul latence
            latency_ms = (time.time() - start_time) * 1000
            self.metrics["avg_latency_ms"] = (
                self.metrics["avg_latency_ms"] * 0.9 + latency_ms * 0.1
            )
            
            # Publication périodique métriques
            if self.metrics["chunks_processed"] % 100 == 0:
                self._publish_metrics()
                
            # Log périodique
            if self.metrics["chunks_processed"] % 500 == 0:
                voice_ratio = (self.metrics["voice_detected"] / 
                             self.metrics["chunks_processed"]) * 100
                self.logger.info(
                    f"Pipeline: {self.metrics['chunks_processed']} chunks, "
                    f"{voice_ratio:.1f}% voix, {self.metrics['avg_latency_ms']:.1f}ms latence"
                )
                
        except Exception as e:
            self.logger.error(f"Erreur callback audio: {e}")
            
    async def start(self):
        """Démarrage pipeline audio"""
        if self.is_running:
            self.logger.warning("Pipeline déjà en cours")
            return
            
        self.logger.info("Démarrage pipeline audio Bender...")
        
        try:
            # Configuration périphérique audio
            device_info = sd.query_devices(self.config.device_name)
            self.logger.info(f"Périphérique: {device_info['name']}")
            
            # Démarrage stream audio
            self.stream = sd.InputStream(
                device=self.config.device_name,
                channels=self.config.channels,
                samplerate=self.config.sample_rate_in,
                dtype=self.config.dtype,
                blocksize=self.config.chunk_size,
                callback=self._audio_callback
            )
            
            self.stream.start()
            self.is_running = True
            
            self.logger.info(
                f"Pipeline démarré: {self.config.sample_rate_in}Hz, "
                f"{self.config.channels}ch, {self.config.dtype}, "
                f"chunk={self.config.chunk_size}"
            )
            
            # Boucle principale
            while self.is_running:
                await asyncio.sleep(1)
                
        except Exception as e:
            self.logger.error(f"Erreur démarrage pipeline: {e}")
            self.is_running = False
            raise
            
    async def stop(self):
        """Arrêt pipeline audio"""
        self.logger.info("Arrêt pipeline audio...")
        
        self.is_running = False
        
        if hasattr(self, 'stream'):
            self.stream.stop()
            self.stream.close()
            
        if self.mqtt_client:
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()
            
        self.logger.info("Pipeline arrêté")
        
# Point d'entrée
async def main():
    """Point d'entrée principal"""
    config = AudioConfig()
    pipeline = AudioPipeline(config)
    
    try:
        await pipeline.start()
    except KeyboardInterrupt:
        print("\nArrêt demandé par utilisateur")
    finally:
        await pipeline.stop()
        
if __name__ == "__main__":
    asyncio.run(main())