# Test automatisé des LEDs ESP32 - Assistant Vocal Bender
# Script de validation du câblage et du firmware

param(
    [string]$ComPort = "COM6",
    [string]$ArduinoPath = "",
    [switch]$SkipUpload,
    [switch]$Verbose
)

# Configuration
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$FirmwarePath = Join-Path $ProjectRoot "firmware\esp32_led_test.ino"
$LogFile = Join-Path $ProjectRoot "logs\esp32_test_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Couleurs pour l'affichage
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'HH:mm:ss') - $Message"
}

function Write-Success { param([string]$Message) Write-ColorOutput $Message "Green" }
function Write-Warning { param([string]$Message) Write-ColorOutput $Message "Yellow" }
function Write-Error { param([string]$Message) Write-ColorOutput $Message "Red" }
function Write-Info { param([string]$Message) Write-ColorOutput $Message "Cyan" }

# Création du dossier logs si nécessaire
$LogDir = Split-Path -Parent $LogFile
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

Write-Info "=== Test LEDs ESP32 - Assistant Vocal Bender ==="
Write-Info "Démarrage du test à $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
Write-Info "Port série: $ComPort"
Write-Info "Firmware: $FirmwarePath"
Write-Info "Log: $LogFile"
Write-Info ""

# Vérification des prérequis
Write-Info "1. Vérification des prérequis..."

# Vérifier que le firmware existe
if (-not (Test-Path $FirmwarePath)) {
    Write-Error "ERREUR: Firmware non trouvé: $FirmwarePath"
    exit 1
}
Write-Success "✓ Firmware trouvé: $FirmwarePath"

# Vérifier le port série
if (-not $SkipUpload) {
    $AvailablePorts = [System.IO.Ports.SerialPort]::getPortNames()
    if ($ComPort -notin $AvailablePorts) {
        Write-Warning "⚠ Port $ComPort non détecté. Ports disponibles: $($AvailablePorts -join ', ')"
        Write-Info "Continuer quand même ? (O/N)"
        $Response = Read-Host
        if ($Response -ne "O" -and $Response -ne "o") {
            Write-Error "Test annulé par l'utilisateur"
            exit 1
        }
    } else {
        Write-Success "✓ Port série $ComPort détecté"
    }
}

# Recherche d'Arduino CLI ou IDE
if (-not $SkipUpload) {
    Write-Info "2. Recherche d'Arduino CLI/IDE..."
    
    $ArduinoCli = $null
    $ArduinoIde = $null
    
    # Recherche Arduino CLI
    $ArduinoCli = Get-Command "arduino-cli" -ErrorAction SilentlyContinue
    if (-not $ArduinoCli) {
        $ArduinoCli = Get-Command "arduino-cli.exe" -ErrorAction SilentlyContinue
    }
    
    # Recherche Arduino IDE
    if ($ArduinoPath -and (Test-Path $ArduinoPath)) {
        $ArduinoIde = $ArduinoPath
    } else {
        $PossiblePaths = @(
            "${env:ProgramFiles}\Arduino IDE\Arduino IDE.exe",
            "${env:ProgramFiles(x86)}\Arduino\arduino.exe",
            "${env:LOCALAPPDATA}\Programs\Arduino IDE\Arduino IDE.exe"
        )
        foreach ($Path in $PossiblePaths) {
            if (Test-Path $Path) {
                $ArduinoIde = $Path
                break
            }
        }
    }
    
    if ($ArduinoCli) {
        Write-Success "✓ Arduino CLI trouvé: $($ArduinoCli.Source)"
        $UseArduinoCli = $true
    } elseif ($ArduinoIde) {
        Write-Success "✓ Arduino IDE trouvé: $ArduinoIde"
        $UseArduinoCli = $false
    } else {
        Write-Error "ERREUR: Ni Arduino CLI ni Arduino IDE trouvés"
        Write-Info "Veuillez installer Arduino CLI ou spécifier le chemin avec -ArduinoPath"
        exit 1
    }
}

# Upload du firmware (si demandé)
if (-not $SkipUpload) {
    Write-Info "3. Compilation et upload du firmware..."
    
    if ($UseArduinoCli) {
        Write-Info "Utilisation d'Arduino CLI..."
        
        # Vérifier la configuration ESP32
        Write-Info "Vérification de la plateforme ESP32..."
        $PlatformCheck = & arduino-cli core list | Select-String "esp32"
        if (-not $PlatformCheck) {
            Write-Warning "Plateforme ESP32 non installée. Installation..."
            & arduino-cli core update-index
            & arduino-cli core install esp32:esp32
        }
        
        # Vérifier FastLED
        Write-Info "Vérification de la bibliothèque FastLED..."
        $FastLedCheck = & arduino-cli lib list | Select-String "FastLED"
        if (-not $FastLedCheck) {
            Write-Warning "Bibliothèque FastLED non installée. Installation..."
            & arduino-cli lib install "FastLED"
        }
        
        # Compilation
        Write-Info "Compilation du firmware..."
        $CompileCmd = "arduino-cli compile --fqbn esp32:esp32:esp32 `"$FirmwarePath`""
        if ($Verbose) { Write-Info "Commande: $CompileCmd" }
        
        $CompileResult = Invoke-Expression $CompileCmd 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "ERREUR de compilation:"
            Write-Error $CompileResult
            exit 1
        }
        Write-Success "✓ Compilation réussie"
        
        # Upload
        Write-Info "Upload vers ESP32 sur $ComPort..."
        $UploadCmd = "arduino-cli upload -p $ComPort --fqbn esp32:esp32:esp32 `"$FirmwarePath`""
        if ($Verbose) { Write-Info "Commande: $UploadCmd" }
        
        $UploadResult = Invoke-Expression $UploadCmd 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "ERREUR d'upload:"
            Write-Error $UploadResult
            exit 1
        }
        Write-Success "✓ Upload réussi sur $ComPort"
        
    } else {
        Write-Warning "Arduino IDE détecté. Veuillez:"
        Write-Warning "1. Ouvrir le fichier: $FirmwarePath"
        Write-Warning "2. Sélectionner la carte: ESP32 Dev Module"
        Write-Warning "3. Sélectionner le port: $ComPort"
        Write-Warning "4. Compiler et uploader (Ctrl+U)"
        Write-Info "Appuyez sur Entrée quand l'upload est terminé..."
        Read-Host
    }
} else {
    Write-Info "Upload ignoré (paramètre -SkipUpload)"
}

# Attendre que l'ESP32 redémarre
Write-Info "4. Attente du redémarrage de l'ESP32..."
Start-Sleep -Seconds 3

# Guide de validation visuelle
Write-Info "5. Validation visuelle des LEDs"
Write-Info ""
Write-Success "=== SÉQUENCE DE TEST ATTENDUE ==="
Write-Info "Le cycle se répète toutes les ~18 secondes:"
Write-Info ""
Write-Info "1. COULEURS GLOBALES (6 secondes):"
Write-Info "   • Toutes LEDs en ROUGE (2s)"
Write-Info "   • Toutes LEDs en VERT (2s)"
Write-Info "   • Toutes LEDs en BLEU (2s)"
Write-Info ""
Write-Info "2. SEGMENTS INDIVIDUELS (4.5 secondes):"
Write-Info "   • Dents uniquement en JAUNE (1.5s)"
Write-Info "   • Œil gauche uniquement en CYAN (1.5s)"
Write-Info "   • Œil droit uniquement en MAGENTA (1.5s)"
Write-Info ""
Write-Info "3. ANIMATION ARC-EN-CIEL (~3 secondes):"
Write-Info "   • Dégradé de couleurs fluide"
Write-Info ""
Write-Info "4. CLIGNOTEMENT BLANC (3 secondes):"
Write-Info "   • 5 clignotements blanc/noir"
Write-Info ""
Write-Info "5. PAUSE (3 secondes):"
Write-Info "   • Toutes LEDs éteintes"
Write-Info ""

# Ouvrir le moniteur série si possible
if (-not $SkipUpload -and $UseArduinoCli) {
    Write-Info "6. Ouverture du moniteur série..."
    Write-Info "Commandes disponibles:"
    Write-Info "• Pour voir les messages: arduino-cli monitor -p $ComPort -c baudrate=115200"
    Write-Info "• Pour arrêter: Ctrl+C"
    Write-Info ""
    
    Write-Info "Voulez-vous ouvrir le moniteur série maintenant ? (O/N)"
    $Response = Read-Host
    if ($Response -eq "O" -or $Response -eq "o") {
        Write-Info "Ouverture du moniteur série... (Ctrl+C pour quitter)"
        & arduino-cli monitor -p $ComPort -c baudrate=115200
    }
}

# Validation finale
Write-Info ""
Write-Success "=== VALIDATION FINALE ==="
Write-Info "Observez les LEDs pendant au moins 2 cycles complets (36 secondes)"
Write-Info ""
Write-Info "✅ CRITÈRES DE SUCCÈS:"
Write-Info "• Messages série visibles (si moniteur ouvert)"
Write-Info "• Les 3 segments s'allument (dents + 2 yeux)"
Write-Info "• Couleurs conformes à la séquence"
Write-Info "• Animation fluide, pas de scintillement"
Write-Info "• Pas de redémarrage en boucle"
Write-Info ""
Write-Info "❌ SIGNES D'ÉCHEC:"
Write-Info "• Aucune LED ne s'allume"
Write-Info "• Un segment ne fonctionne pas"
Write-Info "• Couleurs incorrectes ou aléatoires"
Write-Info "• Scintillement permanent"
Write-Info "• ESP32 redémarre en boucle"
Write-Info ""

Write-Info "Le test est-il RÉUSSI ? (O/N)"
$TestResult = Read-Host

if ($TestResult -eq "O" -or $TestResult -eq "o") {
    Write-Success "✅ TEST RÉUSSI - LEDs ESP32 validées"
    Write-Info "Prochaines étapes:"
    Write-Info "• Documenter les résultats dans METRICS.md"
    Write-Info "• Marquer T1.4 comme terminée dans TODO.md"
    Write-Info "• Passer au développement du firmware MQTT"
    
    # Créer un fichier de résultat
    $ResultFile = Join-Path $ProjectRoot "logs\esp32_test_success_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $ResultContent = @"
Test LEDs ESP32 SUCCES
Date: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
Port: $ComPort
Firmware: $FirmwarePath

Validation:
• 3 segments fonctionnels (dents + 2 yeux)
• Sequence de couleurs correcte
• Animation fluide
• Pas de dysfonctionnement

Prochaines etapes:
• Firmware MQTT final
• Configuration Raspberry Pi 5
"@
    $ResultContent | Out-File -FilePath $ResultFile -Encoding UTF8
    
    Write-Success "Resultats sauvegardes: $ResultFile"
    exit 0
    
} else {
    Write-Error "❌ TEST ÉCHOUÉ - Diagnostic nécessaire"
    Write-Info "Consultez la documentation: docs/ESP32_TEST_INSTRUCTIONS.md"
    Write-Info "Section 'Diagnostic des problèmes' pour le dépannage"
    
    # Créer un fichier d'échec
    $FailFile = Join-Path $ProjectRoot "logs\esp32_test_failed_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $FailContent = @"
Test LEDs ESP32 ECHEC
Date: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
Port: $ComPort
Firmware: $FirmwarePath

Probleme rapporte par l'utilisateur.

Actions de diagnostic recommandees:
1. Verifier l'alimentation 5V (4.8 a 5.2V)
2. Controler les connexions GPIO 16, 17, 21
3. Verifier les resistances 330 ohms
4. Tester avec une seule LED par segment
5. Verifier le condensateur 1000µF
6. Controler la masse commune

Consulter: docs/ESP32_TEST_INSTRUCTIONS.md
"@
    $FailContent | Out-File -FilePath $FailFile -Encoding UTF8
    
    Write-Error "Rapport d'echec sauvegarde: $FailFile"
    exit 1
}