# Script para ejecutar el despliegue local con config de produccion
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$batchFile = Join-Path $scriptPath "deploy_local_produccion_v2.bat"

Write-Host "Ejecutando despliegue local con configuracion de produccion..."
Write-Host "Script: $batchFile"
Write-Host ""

& cmd.exe /c $batchFile

exit $LASTEXITCODE
