param(
    [string]$AvdName = "TravelBox_API_35",
    [switch]$NoWindow,
    [switch]$WipeData
)

$sdkRoot = "C:\Users\GianLH\Desktop\PROYECTI\android-sdk"
$avdHome = "C:\Users\GianLH\Desktop\PROYECTI\android-avd"
$emulator = Join-Path $sdkRoot "emulator\emulator.exe"

$env:ANDROID_SDK_ROOT = $sdkRoot
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_AVD_HOME = $avdHome

$args = @("-avd", $AvdName)
if ($NoWindow) {
    $args += "-no-window"
}
if ($WipeData) {
    $args += "-wipe-data"
}

Start-Process -FilePath $emulator -ArgumentList $args -WorkingDirectory (Split-Path $emulator)

Write-Host "Emulador solicitado: $AvdName"
Write-Host "Si abriste este script con doble clic, la ventana puede cerrarse al terminar."
Write-Host "Para dejar la consola abierta usa:"
Write-Host "powershell -ExecutionPolicy Bypass -NoExit -File .\tools\run_android_emulator.ps1"
