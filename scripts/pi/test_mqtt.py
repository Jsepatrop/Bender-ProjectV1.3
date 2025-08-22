#!/usr/bin/env python3
import socket
import sys

def test_mqtt_connection(host, port):
    """Test MQTT broker connectivity"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(5)
        result = s.connect_ex((host, port))
        s.close()
        
        if result == 0:
            print(f"MQTT: Connexion OK vers {host}:{port}")
            return True
        else:
            print(f"MQTT: Connexion FAIL vers {host}:{port} (code {result})")
            return False
    except Exception as e:
        print(f"MQTT: Erreur {e}")
        return False

if __name__ == "__main__":
    success = test_mqtt_connection("192.168.1.138", 1883)
    sys.exit(0 if success else 1)