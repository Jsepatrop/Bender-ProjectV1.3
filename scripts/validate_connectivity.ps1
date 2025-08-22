#Requires -Version 5.1
<#
.SYNOPSIS
    Script de validation de connectivité pour le projet Bender
.DESCRIPTION
    Teste la connectivité vers toutes les machines du projet
#>

[CmdletBinding()]
param()

# Configuration
$ErrorActionPreference = 'Continue'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$EnvFile = Join-Path $ProjectRoot '.env.local'

Write-Host "=== VALIDATION CONNECTIVITE BENDER ===" -ForegroundColor Cyan
Write-Host "Fichier config: $EnvFile" -ForegroundColor Gray
Write-Host ""

# Vérifier que .env.local existe
if (-not (Test-Path $EnvFile)) {
    Write-Host "ERREUR: Fichier .env.local introuvable" -ForegroundColor Red
    Write-Host "   Créer le fichier avec les informations de connexion" -ForegroundColor Yellow
    exit 1
}

# Parse .env.local
$config = @{}
try {
    Get-Content $EnvFile -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
            $parts = $line.Split('=', 2)
            if ($parts.Length -eq 2) {
                $key = $parts[0].Trim()
                $value = $parts[1].Trim().Trim('"').Trim("'")
                $config[$key] = $value
            }
        }
    }
    Write-Host "Configuration chargee ($($config.Count) parametres)" -ForegroundColor Green
} catch {
    Write-Host "ERREUR: Impossible de lire .env.local" -ForegroundColor Red
    Write-Host "   $_" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# === TEST 1: RASPBERRY PI 5 ===
Write-Host "TEST 1: Raspberry Pi 5" -ForegroundColor Cyan
$pi5_host = $config['PI5_HOST']
if ($pi5_host) {
    Write-Host "   Ping $pi5_host..." -NoNewline
    $ping = Test-Connection -ComputerName $pi5_host -Count 2 -Quiet
    if ($ping) {
        Write-Host " OK" -ForegroundColor Green
        
        # Test SSH
        Write-Host "   SSH $pi5_host..." -NoNewline
        try {
            $sshTest = ssh -o ConnectTimeout=5 -o BatchMode=yes "$($config['PI5_USER'])@$pi5_host" 'echo SSH_OK' 2>$null
            if ($sshTest -eq 'SSH_OK') {
                Write-Host " OK" -ForegroundColor Green
            } else {
                Write-Host " Cle SSH requise" -ForegroundColor Yellow
            }
        } catch {
            Write-Host " ECHEC" -ForegroundColor Red
            Write-Host "      Verifier cle SSH et utilisateur" -ForegroundColor Yellow
        }
    } else {
        Write-Host " ECHEC" -ForegroundColor Red
        Write-Host "      Verifier IP et reseau" -ForegroundColor Yellow
    }
} else {
    Write-Host "   PI5_HOST non defini dans .env.local" -ForegroundColor Red
}
Write-Host ""

# === TEST 2: DELL T630 ===
Write-Host "TEST 2: Dell T630" -ForegroundColor Cyan
$t630_host = $config['T630_HOST']
if ($t630_host) {
    Write-Host "   Ping $t630_host..." -NoNewline
    $ping = Test-Connection -ComputerName $t630_host -Count 2 -Quiet
    if ($ping) {
        Write-Host " ✅ OK" -ForegroundColor Green
        
        # Test WinRM si credentials disponibles
        $t630_user = $config['T630_USER']
        $t630_pass = $config['T630_PASS']
        if ($t630_user -and $t630_pass) {
            Write-Host "   WinRM $t630_host..." -NoNewline
            try {
                $secPass = ConvertTo-SecureString $t630_pass -AsPlainText -Force
                $cred = New-Object System.Management.Automation.PSCredential($t630_user, $secPass)
                $session = New-PSSession -ComputerName $t630_host -Credential $cred -ErrorAction Stop
                if ($session) {
                    Write-Host " OK" -ForegroundColor Green
                    Remove-PSSession $session
                } else {
                    Write-Host " ECHEC" -ForegroundColor Red
                }
            } catch {
                Write-Host " ECHEC: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "      Verifier credentials et WinRM" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   WinRM: Credentials manquants" -ForegroundColor Yellow
        }
    } else {
        Write-Host " ECHEC" -ForegroundColor Red
        Write-Host "      Verifier IP et reseau" -ForegroundColor Yellow
    }
} else {
    Write-Host "   T630_HOST non defini dans .env.local" -ForegroundColor Red
}
Write-Host ""

# === TEST 3: HOME ASSISTANT ===
Write-Host "TEST 3: Home Assistant" -ForegroundColor Cyan
$ha_url = $config['HA_URL']
if ($ha_url) {
    Write-Host "   API $ha_url..." -NoNewline
    try {
        $response = Invoke-WebRequest -Uri $ha_url -Method GET -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Host " Code: $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " ECHEC: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "      Verifier URL et certificats" -ForegroundColor Yellow
    }
} else {
    Write-Host "   HA_URL non defini dans .env.local" -ForegroundColor Red
}
Write-Host ""

# === TEST 4: MQTT BROKER ===
Write-Host "TEST 4: MQTT Broker" -ForegroundColor Cyan
$mqtt_host = $config['MQTT_HOST']
$mqtt_port = $config['MQTT_PORT_PLAIN']
if ($mqtt_host -and $mqtt_port) {
    Write-Host "   Port TCP $mqtt_host`:$mqtt_port..." -NoNewline
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.ConnectAsync($mqtt_host, [int]$mqtt_port)
        $connect.Wait(5000)
        if ($tcpClient.Connected) {
            Write-Host " OK" -ForegroundColor Green
            $tcpClient.Close()
        } else {
            Write-Host " ECHEC" -ForegroundColor Red
        }
    } catch {
        Write-Host " ECHEC: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "      Verifier broker MQTT et port" -ForegroundColor Yellow
    }
} else {
    Write-Host "   MQTT_HOST ou MQTT_PORT_PLAIN non defini" -ForegroundColor Red
}
Write-Host ""

# === TEST 5: ESP32 PORT SÉRIE ===
Write-Host "TEST 5: ESP32 Port Serie" -ForegroundColor Cyan
$esp32_port = $config['ESP32_PORT']
if ($esp32_port) {
    Write-Host "   Port $esp32_port..." -NoNewline
    try {
        $ports = [System.IO.Ports.SerialPort]::GetPortNames()
        if ($ports -contains $esp32_port) {
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Host " ECHEC" -ForegroundColor Red
            Write-Host "      Verifier connexion USB ESP32" -ForegroundColor Yellow
            Write-Host "      Ports disponibles:" -ForegroundColor Yellow
            Get-WmiObject Win32_SerialPort | ForEach-Object {
                Write-Host "        $($_.DeviceID): $($_.Description)" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host " ECHEC: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   ESP32_PORT non defini dans .env.local" -ForegroundColor Red
}
Write-Host ""

Write-Host "=== VALIDATION TERMINEE ===" -ForegroundColor Cyan
Write-Host "Verifier les echecs avant de continuer le deploiement" -ForegroundColor Yellow