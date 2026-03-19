param(
    [switch]$ShowConsoles,
    [switch]$SkipWebBuild,
    [switch]$MobileProfile,
    [switch]$SkipFrontendClean,
    [switch]$SkipBackendClean,
    [int]$WebPort = 8088
)

$ErrorActionPreference = "Stop"

$appRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $appRoot
$backendRoot = Join-Path $workspaceRoot "TravelBox_Peru_Backend"
$deployAllScript = Join-Path $workspaceRoot "deploy_all.ps1"

function Write-Step {
    param(
        [int]$Percent,
        [string]$Status
    )
    Write-Progress -Id 1 -Activity "TravelBox local reset + restart" -Status $Status -PercentComplete $Percent
    Write-Host ("[{0,3}%] {1}" -f $Percent, $Status)
}

function Stop-ByCommandPattern {
    param([string]$Pattern)
    $matches = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like $Pattern }
    foreach ($process in $matches) {
        if ($process.ProcessId -and $process.ProcessId -ne $PID) {
            Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
        }
    }
}

function Stop-ProcessListeningOnPort {
    param([int]$Port)
    $listeners = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($processId in $listeners) {
        if ($processId -and $processId -ne $PID) {
            Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        }
    }
}

if (-not (Test-Path $deployAllScript)) {
    throw "No se encontro deploy_all.ps1 en: $deployAllScript"
}

Write-Step -Percent 5 -Status "Deteniendo procesos y puertos locales..."
Stop-ProcessListeningOnPort -Port 8080
Stop-ProcessListeningOnPort -Port $WebPort
Stop-ProcessListeningOnPort -Port 8090
Stop-ByCommandPattern -Pattern "*TravelBox_Peru_Backend*spring-boot:run*"
Stop-ByCommandPattern -Pattern "*spa_server.py*--port *"
Stop-ByCommandPattern -Pattern "*flutter*run -d emulator-*"
Stop-ByCommandPattern -Pattern "*flutter*run -d chrome*"

if (-not $SkipFrontendClean) {
    Write-Step -Percent 20 -Status "Limpiando cache frontend (flutter clean)..."
    Push-Location $appRoot
    try {
        & flutter clean
        if ($LASTEXITCODE -ne 0) {
            throw "flutter clean fallo."
        }
        Write-Step -Percent 32 -Status "Restaurando dependencias frontend (flutter pub get)..."
        & flutter pub get
        if ($LASTEXITCODE -ne 0) {
            throw "flutter pub get fallo."
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Step -Percent 32 -Status "Salto limpieza frontend por parametro."
}

if (-not $SkipBackendClean -and (Test-Path $backendRoot)) {
    Write-Step -Percent 45 -Status "Limpiando/compilando backend (mvn clean compile)..."
    Push-Location $backendRoot
    try {
        & .\mvnw.cmd -DskipTests clean compile
        if ($LASTEXITCODE -ne 0) {
            throw "mvnw clean compile fallo."
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Step -Percent 45 -Status "Salto limpieza backend por parametro."
}

Write-Step -Percent 65 -Status "Levantando backend + web + mobile con deploy_all.ps1..."
$deployArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $deployAllScript,
    "-ForceRestart",
    "-WebPort", "$WebPort"
)
if ($ShowConsoles) { $deployArgs += "-ShowConsoles" }
if ($SkipWebBuild) { $deployArgs += "-SkipWebBuild" }
if ($MobileProfile) { $deployArgs += "-MobileProfile" }

& powershell @deployArgs
if ($LASTEXITCODE -ne 0) {
    throw "deploy_all.ps1 termino con error."
}

Write-Step -Percent 100 -Status "Proceso local completado."
Write-Progress -Id 1 -Activity "TravelBox local reset + restart" -Completed
Write-Host ""
Write-Host "Listo. Servicios esperados:"
Write-Host " - Backend: http://localhost:8080"
Write-Host " - API:     http://localhost:8080/api/v1"
Write-Host " - Web:     http://127.0.0.1:$WebPort"
