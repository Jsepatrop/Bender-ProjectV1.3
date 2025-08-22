#!/usr/bin/env python3
"""
Bender UI - Interface Web FastAPI
Application principale pour l'interface utilisateur de Bender
"""

import os
import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

# Configuration
app = FastAPI(
    title="Bender UI",
    description="Interface utilisateur pour l'assistant vocal Bender",
    version="1.0.0"
)

# CORS pour le développement
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # À restreindre en production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("bender.ui")

# Modèles Pydantic
class SystemStatus(BaseModel):
    timestamp: str
    services: Dict[str, bool]
    system: Dict[str, float]
    audio: Dict[str, str]

class VoiceConfig(BaseModel):
    voice_id: str
    model_path: str
    checksum: str
    enabled: bool

class AudioSettings(BaseModel):
    input_device: str
    output_device: str
    sample_rate: int
    channels: int
    aec_enabled: bool
    vad_enabled: bool

# Variables globales
connected_clients: List[WebSocket] = []
system_status = {
    "timestamp": datetime.now().isoformat(),
    "services": {
        "audio_pipeline": False,
        "intent_router": False,
        "mqtt": False,
        "home_assistant": False
    },
    "system": {
        "cpu_percent": 0.0,
        "memory_percent": 0.0,
        "disk_percent": 0.0,
        "temperature": 0.0
    },
    "audio": {
        "input_level": "0",
        "output_level": "0",
        "status": "idle"
    }
}

# Routes API
@app.get("/")
async def root():
    """Page d'accueil - sert le frontend React"""
    return FileResponse("static/index.html")

@app.get("/api/status")
async def get_status() -> SystemStatus:
    """Récupère le statut système actuel"""
    return SystemStatus(**system_status)

@app.get("/api/voices")
async def get_voices() -> List[VoiceConfig]:
    """Liste les voix disponibles"""
    # TODO: Implémenter la lecture des voix Piper
    return [
        VoiceConfig(
            voice_id="fr-siwis-medium",
            model_path="/opt/bender/voices/fr-siwis-medium.onnx",
            checksum="sha256:...",
            enabled=True
        )
    ]

@app.get("/api/audio/settings")
async def get_audio_settings() -> AudioSettings:
    """Récupère les paramètres audio actuels"""
    # TODO: Lire la configuration audio réelle
    return AudioSettings(
        input_device="hw:0,0",
        output_device="hw:0,1",
        sample_rate=48000,
        channels=2,
        aec_enabled=True,
        vad_enabled=True
    )

@app.post("/api/audio/settings")
async def update_audio_settings(settings: AudioSettings):
    """Met à jour les paramètres audio"""
    # TODO: Appliquer les nouveaux paramètres
    logger.info(f"Nouveaux paramètres audio: {settings}")
    return {"status": "success", "message": "Paramètres audio mis à jour"}

@app.post("/api/tts/say")
async def say_text(text: str):
    """Fait dire un texte par Bender"""
    # TODO: Publier sur MQTT bender/tts/say
    logger.info(f"TTS demandé: {text}")
    return {"status": "success", "message": f"Texte envoyé: {text}"}

@app.post("/api/system/restart")
async def restart_system():
    """Redémarre les services Bender"""
    # TODO: Redémarrer les services systemd
    logger.info("Redémarrage des services demandé")
    return {"status": "success", "message": "Services en cours de redémarrage"}

# WebSocket pour les mises à jour temps réel
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket pour les mises à jour temps réel"""
    await websocket.accept()
    connected_clients.append(websocket)
    logger.info(f"Client WebSocket connecté. Total: {len(connected_clients)}")
    
    try:
        while True:
            # Envoyer le statut actuel
            await websocket.send_json(system_status)
            await websocket.receive_text()  # Attendre un ping du client
    except WebSocketDisconnect:
        connected_clients.remove(websocket)
        logger.info(f"Client WebSocket déconnecté. Total: {len(connected_clients)}")

# Fonction utilitaire pour broadcaster aux clients WebSocket
async def broadcast_status():
    """Diffuse le statut à tous les clients connectés"""
    if connected_clients:
        for client in connected_clients.copy():
            try:
                await client.send_json(system_status)
            except:
                connected_clients.remove(client)

# Montage des fichiers statiques (React build)
app.mount("/static", StaticFiles(directory="static"), name="static")

if __name__ == "__main__":
    # Configuration pour le développement
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=8080,
        reload=True,
        ssl_keyfile=None,  # TODO: Ajouter TLS en production
        ssl_certfile=None
    )