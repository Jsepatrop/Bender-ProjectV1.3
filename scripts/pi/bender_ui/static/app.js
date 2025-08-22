/**
 * Bender UI - Application JavaScript
 * Gestion de l'interface utilisateur et communication WebSocket
 */

class BenderUI {
    constructor() {
        this.ws = null;
        this.reconnectInterval = 5000;
        this.maxReconnectAttempts = 10;
        this.reconnectAttempts = 0;
        
        this.init();
    }

    init() {
        console.log('Initialisation Bender UI...');
        
        // Initialiser les événements
        this.setupEventListeners();
        
        // Connecter WebSocket
        this.connectWebSocket();
        
        // Charger le statut initial
        this.loadInitialStatus();
    }

    setupEventListeners() {
        // Bouton TTS
        document.getElementById('tts-speak').addEventListener('click', () => {
            this.speakText();
        });

        // Entrée TTS (Enter)
        document.getElementById('tts-text').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.speakText();
            }
        });

        // Redémarrer services
        document.getElementById('restart-services').addEventListener('click', () => {
            this.restartServices();
        });

        // Actualiser statut
        document.getElementById('refresh-status').addEventListener('click', () => {
            this.refreshStatus();
        });

        // Sauvegarder config audio
        document.getElementById('save-audio').addEventListener('click', () => {
            this.saveAudioSettings();
        });
    }

    connectWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}/ws`;
        
        console.log(`Connexion WebSocket: ${wsUrl}`);
        
        this.ws = new WebSocket(wsUrl);
        
        this.ws.onopen = () => {
            console.log('WebSocket connecté');
            this.reconnectAttempts = 0;
            this.updateConnectionStatus(true);
            
            // Envoyer un ping périodique
            this.startPing();
        };
        
        this.ws.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                this.updateStatus(data);
            } catch (error) {
                console.error('Erreur parsing WebSocket:', error);
            }
        };
        
        this.ws.onclose = () => {
            console.log('WebSocket fermé');
            this.updateConnectionStatus(false);
            this.scheduleReconnect();
        };
        
        this.ws.onerror = (error) => {
            console.error('Erreur WebSocket:', error);
            this.updateConnectionStatus(false);
        };
    }

    startPing() {
        this.pingInterval = setInterval(() => {
            if (this.ws && this.ws.readyState === WebSocket.OPEN) {
                this.ws.send('ping');
            }
        }, 30000); // Ping toutes les 30 secondes
    }

    scheduleReconnect() {
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            console.log(`Tentative de reconnexion ${this.reconnectAttempts}/${this.maxReconnectAttempts} dans ${this.reconnectInterval/1000}s`);
            
            setTimeout(() => {
                this.connectWebSocket();
            }, this.reconnectInterval);
        } else {
            console.error('Nombre maximum de tentatives de reconnexion atteint');
            this.addLog('Connexion WebSocket échouée après plusieurs tentatives', 'error');
        }
    }

    updateConnectionStatus(connected) {
        const indicator = document.getElementById('connection-status');
        const text = document.getElementById('connection-text');
        
        if (connected) {
            indicator.className = 'status-indicator status-online';
            text.textContent = 'Connecté';
        } else {
            indicator.className = 'status-indicator status-offline';
            text.textContent = 'Déconnecté';
        }
    }

    updateStatus(data) {
        console.log('Mise à jour statut:', data);
        
        // Mettre à jour les services
        if (data.services) {
            this.updateServicesStatus(data.services);
        }
        
        // Mettre à jour les métriques système
        if (data.system) {
            this.updateSystemMetrics(data.system);
        }
        
        // Mettre à jour l'audio
        if (data.audio) {
            this.updateAudioStatus(data.audio);
        }
        
        // Ajouter au log
        this.addLog(`Statut mis à jour: ${new Date().toLocaleTimeString()}`, 'info');
    }

    updateServicesStatus(services) {
        const container = document.getElementById('services-status');
        const serviceNames = {
            'audio_pipeline': 'Pipeline Audio',
            'intent_router': 'Router Intents',
            'mqtt': 'MQTT',
            'home_assistant': 'Home Assistant'
        };
        
        container.innerHTML = '';
        
        Object.entries(services).forEach(([key, status]) => {
            const div = document.createElement('div');
            const statusClass = status ? 'status-online' : 'status-offline';
            div.innerHTML = `<span class="status-indicator ${statusClass}"></span>${serviceNames[key] || key}`;
            container.appendChild(div);
        });
    }

    updateSystemMetrics(system) {
        // CPU
        const cpuProgress = document.getElementById('cpu-progress');
        if (cpuProgress && system.cpu_percent !== undefined) {
            const cpu = Math.round(system.cpu_percent);
            cpuProgress.style.width = `${cpu}%`;
            cpuProgress.textContent = `${cpu}%`;
            cpuProgress.className = `progress-bar ${cpu > 80 ? 'bg-danger' : cpu > 60 ? 'bg-warning' : 'bg-success'}`;
        }
        
        // Mémoire
        const memoryProgress = document.getElementById('memory-progress');
        if (memoryProgress && system.memory_percent !== undefined) {
            const memory = Math.round(system.memory_percent);
            memoryProgress.style.width = `${memory}%`;
            memoryProgress.textContent = `${memory}%`;
            memoryProgress.className = `progress-bar ${memory > 80 ? 'bg-danger' : memory > 60 ? 'bg-warning' : 'bg-success'}`;
        }
        
        // Disque
        const diskProgress = document.getElementById('disk-progress');
        if (diskProgress && system.disk_percent !== undefined) {
            const disk = Math.round(system.disk_percent);
            diskProgress.style.width = `${disk}%`;
            diskProgress.textContent = `${disk}%`;
            diskProgress.className = `progress-bar ${disk > 90 ? 'bg-danger' : disk > 70 ? 'bg-warning' : 'bg-success'}`;
        }
        
        // Température
        const temperature = document.getElementById('temperature');
        if (temperature && system.temperature !== undefined) {
            temperature.textContent = `${Math.round(system.temperature)}°C`;
        }
    }

    updateAudioStatus(audio) {
        const inputLevel = document.getElementById('audio-input');
        const outputLevel = document.getElementById('audio-output');
        const status = document.getElementById('audio-status');
        
        if (inputLevel && audio.input_level !== undefined) {
            inputLevel.textContent = audio.input_level;
        }
        
        if (outputLevel && audio.output_level !== undefined) {
            outputLevel.textContent = audio.output_level;
        }
        
        if (status && audio.status !== undefined) {
            status.textContent = audio.status;
        }
    }

    async loadInitialStatus() {
        try {
            const response = await fetch('/api/status');
            if (response.ok) {
                const data = await response.json();
                this.updateStatus(data);
            }
        } catch (error) {
            console.error('Erreur chargement statut initial:', error);
            this.addLog('Erreur lors du chargement du statut initial', 'error');
        }
    }

    async speakText() {
        const textInput = document.getElementById('tts-text');
        const text = textInput.value.trim();
        
        if (!text) {
            this.addLog('Aucun texte à faire parler', 'warning');
            return;
        }
        
        try {
            const response = await fetch('/api/tts/say', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ text: text })
            });
            
            if (response.ok) {
                const result = await response.json();
                this.addLog(`TTS: ${text}`, 'success');
            } else {
                throw new Error(`Erreur HTTP: ${response.status}`);
            }
        } catch (error) {
            console.error('Erreur TTS:', error);
            this.addLog(`Erreur TTS: ${error.message}`, 'error');
        }
    }

    async restartServices() {
        if (!confirm('Êtes-vous sûr de vouloir redémarrer les services ?')) {
            return;
        }
        
        try {
            const response = await fetch('/api/system/restart', {
                method: 'POST'
            });
            
            if (response.ok) {
                const result = await response.json();
                this.addLog('Services en cours de redémarrage...', 'info');
            } else {
                throw new Error(`Erreur HTTP: ${response.status}`);
            }
        } catch (error) {
            console.error('Erreur redémarrage:', error);
            this.addLog(`Erreur redémarrage: ${error.message}`, 'error');
        }
    }

    async refreshStatus() {
        await this.loadInitialStatus();
        this.addLog('Statut actualisé', 'info');
    }

    async saveAudioSettings() {
        const settings = {
            input_device: document.getElementById('input-device').value,
            output_device: document.getElementById('output-device').value,
            sample_rate: parseInt(document.getElementById('sample-rate').value),
            channels: 2,
            aec_enabled: document.getElementById('aec-enabled').checked,
            vad_enabled: document.getElementById('vad-enabled').checked
        };
        
        try {
            const response = await fetch('/api/audio/settings', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(settings)
            });
            
            if (response.ok) {
                const result = await response.json();
                this.addLog('Paramètres audio sauvegardés', 'success');
            } else {
                throw new Error(`Erreur HTTP: ${response.status}`);
            }
        } catch (error) {
            console.error('Erreur sauvegarde audio:', error);
            this.addLog(`Erreur sauvegarde: ${error.message}`, 'error');
        }
    }

    addLog(message, type = 'info') {
        const logsContainer = document.getElementById('logs');
        const timestamp = new Date().toLocaleTimeString();
        
        const logEntry = document.createElement('div');
        logEntry.style.marginBottom = '5px';
        
        let color = '#ffffff';
        switch (type) {
            case 'error': color = '#ff6b6b'; break;
            case 'warning': color = '#ffd93d'; break;
            case 'success': color = '#6bcf7f'; break;
            case 'info': color = '#74c0fc'; break;
        }
        
        logEntry.innerHTML = `<span style="color: #888;">[${timestamp}]</span> <span style="color: ${color};">${message}</span>`;
        
        logsContainer.appendChild(logEntry);
        logsContainer.scrollTop = logsContainer.scrollHeight;
        
        // Limiter le nombre de logs
        const logs = logsContainer.children;
        if (logs.length > 100) {
            logsContainer.removeChild(logs[0]);
        }
    }
}

// Initialiser l'application au chargement de la page
document.addEventListener('DOMContentLoaded', () => {
    window.benderUI = new BenderUI();
});