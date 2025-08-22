# Script de transfert du pipeline audio vers le Pi
# Encode le fichier en base64 et le transfère via SSH

$sourceFile = "C:\Users\jsepa\Desktop\Bender Project V1.2\scripts\pi\audio_pipeline.py"
$content = Get-Content $sourceFile -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
$encoded = [System.Convert]::ToBase64String($bytes)

# Commande SSH pour décoder et installer
$sshCommand = @"
sudo bash -c 'echo "$encoded" | base64 -d > /tmp/audio_pipeline_new.py && cp /tmp/audio_pipeline_new.py /opt/bender/audio_pipeline.py && chown bender:bender /opt/bender/audio_pipeline.py && chmod 755 /opt/bender/audio_pipeline.py && systemctl restart bender-audio.service'
"@

Write-Host "Transfert du pipeline audio..."
ssh pi@192.168.1.104 $sshCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host "Pipeline transféré avec succès"
    ssh pi@192.168.1.104 "sudo systemctl status bender-audio.service --no-pager -l"
} else {
    Write-Host "Erreur lors du transfert"
}