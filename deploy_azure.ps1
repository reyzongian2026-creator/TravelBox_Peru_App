<#
.SYNOPSIS
    TravelBox Peru Frontend - Despliegue completo a Azure Static Web Apps
.DESCRIPTION
    Script consolidado 100% Azure para compilar Flutter Web y desplegar
    a Azure Static Web Apps. Incluye: Key Vault secrets, build con dart-define,
    deploy via SWA CLI o az staticwebapp.
.PARAMETER Action
    Accion a ejecutar: deploy (default), build-only, config-only, status, local
.PARAMETER Environment
    Entorno destino: prod (default)
.PARAMETER SkipBuild
    Omitir compilacion Flutter y usar build existente
.PARAMETER ApiBaseUrl
    URL base del API backend (default: https://api.inkavoy.pe/api/v1)
.PARAMETER Verbose
    Mostrar output detallado
.EXAMPLE
    .\deploy_azure.ps1
    .\deploy_azure.ps1 -Action deploy
    .\deploy_azure.ps1 -Action build-only
    .\deploy_azure.ps1 -Action local
    .\deploy_azure.ps1 -Action status
    .\deploy_azure.ps1 -SkipBuild
#>

param(
    [ValidateSet("deploy", "build-only", "config-only", "status", "local")]
    [string]$Action = "deploy",

    [ValidateSet("prod")]
    [string]$Environment = "prod",

    [switch]$SkipBuild,

    [string]$ApiBaseUrl = "https://api.inkavoy.pe/api/v1",

    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ============================================================================
# CONFIGURACION AZURE
# ============================================================================
$AZURE = @{
    SubscriptionId   = "33815caa-4cfb-4a9e-b60a-8fee5caa2b08"
    ResourceGroup    = "travelbox-peru-rg"
    StaticWebAppName = "travelbox-frontend"
    KeyVaultName     = "kvtravelboxpebs"
    Region           = "eastus"
}

$FLUTTER = @{
    Version  = "3.41.5"
    BuildDir = "build\web"
    Channel  = "stable"
}

$URLS = @{
    FrontendPublic = "https://www.inkavoy.pe"
    BackendApi     = $ApiBaseUrl
}

# ============================================================================
# KEY VAULT SECRETS PARA FRONTEND (build-time dart-define)
# ============================================================================
$KV_FRONTEND_SECRETS = @(
    @{ Secret = "tbx-azure-client-id"; Env = "AZURE_CLIENT_ID"; Required = $false }
    @{ Secret = "tbx-azure-tenant-id"; Env = "AZURE_TENANT_ID"; Required = $false }
    @{ Secret = "tbx-azure-maps-api-key"; Env = "AZURE_MAPS_API_KEY"; Required = $false }
    @{ Secret = "tbx-app-google-maps-api-key"; Env = "GOOGLE_MAPS_API_KEY"; Required = $false }
)

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

function Write-Step {
    param([string]$Step, [string]$Message)
    Write-Host "`n[$Step] " -ForegroundColor Cyan -NoNewline
    Write-Host $Message -ForegroundColor White
}

function Write-Ok {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  [ERROR] $Message" -ForegroundColor Red
}

function Test-AzureCli {
    $azVersion = az version 2>$null | ConvertFrom-Json
    if (-not $azVersion) {
        Write-Fail "Azure CLI no esta instalado. Instalar desde https://aka.ms/installazurecli"
        exit 1
    }
    Write-Ok "Azure CLI v$($azVersion.'azure-cli')"
}

function Test-AzureLogin {
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Step "AUTH" "Iniciando login de Azure..."
        az login
        $account = az account show | ConvertFrom-Json
    }
    az account set --subscription $AZURE.SubscriptionId
    Write-Ok "Suscripcion: $($account.name) ($($AZURE.SubscriptionId))"
}

function Test-FlutterSdk {
    try {
        $flutterVersion = flutter --version 2>&1 | Select-String "Flutter" | Select-Object -First 1
        if ($flutterVersion) {
            Write-Ok "Flutter detectado: $($flutterVersion.ToString().Trim())"
            return
        }
    }
    catch {}
    Write-Fail "Flutter SDK no detectado. Instalar desde https://flutter.dev"
    exit 1
}

function Test-SwaCli {
    try {
        $oldPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $swaVersion = swa --version 2>&1
        $ErrorActionPreference = $oldPref
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "SWA CLI v$($swaVersion.ToString().Trim())"
            return $true
        }
    }
    catch {}
    Write-Warn "SWA CLI no instalado. Intentando con az staticwebapp..."
    return $false
}

function Get-FrontendSecrets {
    Write-Step "KEY VAULT" "Obteniendo secretos de $($AZURE.KeyVaultName)..."
    $secrets = @{}

    foreach ($item in $KV_FRONTEND_SECRETS) {
        $oldPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $value = az keyvault secret show `
            --vault-name $AZURE.KeyVaultName `
            --name $item.Secret `
            --query value -o tsv 2>$null
        $ErrorActionPreference = $oldPref

        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($value)) {
            $secrets[$item.Env] = $value
            if ($VerboseOutput) { Write-Ok "$($item.Secret) -> $($item.Env)" }
        }
        else {
            if ($item.Required) {
                Write-Fail "Secret requerido no encontrado: $($item.Secret)"
                exit 1
            }
            if ($VerboseOutput) { Write-Warn "$($item.Secret) no encontrado (opcional)" }
        }
    }

    Write-Ok "$($secrets.Count) secretos obtenidos"
    return $secrets
}

function Build-Flutter {
    param([hashtable]$Secrets)

    Write-Step "BUILD" "Compilando Flutter Web (release)..."

    $projectRoot = $PSScriptRoot
    Push-Location $projectRoot

    try {
        # Limpiar build anterior
        if (Test-Path $FLUTTER.BuildDir) {
            Remove-Item -Recurse -Force $FLUTTER.BuildDir
            Write-Ok "Build anterior limpiado"
        }

        # Flutter pub get
        Write-Host "  Obteniendo dependencias..."
        flutter pub get | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "flutter pub get fallo"
            exit 1
        }

        # Construir argumentos dart-define
        $dartDefines = @(
            "--dart-define=APP_ENV=$Environment"
            "--dart-define=USE_MOCK_FALLBACK=false"
            "--dart-define=API_BASE_URL=$($URLS.BackendApi)"
            "--dart-define=FORCE_CASH_PAYMENTS_ONLY=false"
            "--dart-define=AZURE_STORAGE_UPLOADS_ENABLED=true"
        )

        # Agregar secrets de Key Vault como dart-define
        foreach ($kv in $Secrets.GetEnumerator()) {
            $dartDefines += "--dart-define=$($kv.Key)=$($kv.Value)"
        }

        Write-Host "  Compilando con $($dartDefines.Count) dart-defines..."
        if ($VerboseOutput) {
            $dartDefines | ForEach-Object {
                $display = $_
                if ($display -match "(KEY|SECRET|PASSWORD|TOKEN)=") {
                    $display = $display -replace "=.*$", "=***"
                }
                Write-Host "    $display" -ForegroundColor DarkGray
            }
        }

        # Build command
        $buildArgs = @("build", "web", "--release") + $dartDefines
        & flutter @buildArgs | Out-Host

        if ($LASTEXITCODE -ne 0) {
            Write-Fail "flutter build web fallo"
            exit 1
        }

        # Verificar output
        $indexHtml = Join-Path $FLUTTER.BuildDir "index.html"
        if (-not (Test-Path $indexHtml)) {
            Write-Fail "index.html no generado en $($FLUTTER.BuildDir)"
            exit 1
        }

        $fileCount = (Get-ChildItem -Recurse -File $FLUTTER.BuildDir).Count
        $totalSize = [math]::Round(((Get-ChildItem -Recurse -File $FLUTTER.BuildDir | Measure-Object -Property Length -Sum).Sum / 1MB), 1)
        Write-Ok "Build completado: $fileCount archivos, $totalSize MB"

        return (Resolve-Path $FLUTTER.BuildDir).Path
    }
    finally {
        Pop-Location
    }
}

function Deploy-ToStaticWebApp {
    param([string]$BuildPath)

    Write-Step "DEPLOY" "Desplegando a Azure Static Web Apps..."

    # Intentar obtener el deployment token
    $oldPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $deployToken = az staticwebapp secrets list `
        --resource-group $AZURE.ResourceGroup `
        --name $AZURE.StaticWebAppName `
        --query "properties.apiKey" -o tsv 2>$null
    $ErrorActionPreference = $oldPref

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($deployToken)) {
        Write-Fail "No se pudo obtener el deployment token de $($AZURE.StaticWebAppName)"
        Write-Host "  Verifica que el recurso existe en el Resource Group $($AZURE.ResourceGroup)"
        exit 1
    }

    # Intentar primero con SWA CLI (mejor experiencia)
    $hasSwa = Test-SwaCli
    if ($hasSwa) {
        Write-Host "  Desplegando con SWA CLI..."
        swa deploy $BuildPath `
            --deployment-token $deployToken `
            --env production

        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Despliegue exitoso via SWA CLI"
            return
        }
        Write-Warn "SWA CLI fallo, intentando metodo alternativo..."
    }

    # Fallback: zip + az staticwebapp
    Write-Host "  Creando archivo ZIP del build..."
    $zipPath = Join-Path $env:TEMP "travelbox-frontend-build.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

    Compress-Archive -Path "$BuildPath\*" -DestinationPath $zipPath -Force

    $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
    Write-Host "  Subiendo ZIP ($zipSize MB)..."

    # Use the deployment token with SWA deploy API
    $headers = @{
        "Authorization" = "Bearer $deployToken"
        "Content-Type"  = "application/zip"
    }

    # Alternative: use az directly if available
    $oldPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    az staticwebapp deploy `
        --resource-group $AZURE.ResourceGroup `
        --name $AZURE.StaticWebAppName `
        --input-location $BuildPath `
        --output-location "/" 2>$null
    $ErrorActionPreference = $oldPref

    if ($LASTEXITCODE -ne 0) {
        # Last resort: manual upload instructions
        Write-Warn "Despliegue automatico no disponible con las herramientas actuales."
        Write-Host ""
        Write-Host "  Opciones manuales:" -ForegroundColor Yellow
        Write-Host "  1. Instalar SWA CLI: npm install -g @azure/static-web-apps-cli"
        Write-Host "     swa deploy $BuildPath --deployment-token $deployToken --env production"
        Write-Host ""
        Write-Host "  2. Hacer push a 'main' en GitHub (auto-deploy via GitHub Actions)"
        Write-Host ""
        Write-Host "  3. Desde Azure Portal > Static Web Apps > $($AZURE.StaticWebAppName) > Deploy"
        Write-Host ""
        Write-Host "  El build esta listo en: $BuildPath"
        return
    }

    Write-Ok "Despliegue completado"

    # Cleanup
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
}

function Show-Status {
    Write-Step "STATUS" "Estado de Azure Static Web App..."

    $swa = az staticwebapp show `
        --resource-group $AZURE.ResourceGroup `
        --name $AZURE.StaticWebAppName `
        --query "{defaultHostname:defaultHostname, customDomains:customDomains, sku:sku.name, branch:repositoryBranch}" `
        -o json 2>$null | ConvertFrom-Json

    if ($swa) {
        Write-Host "  Hostname:  https://$($swa.defaultHostname)"
        Write-Host "  SKU:       $($swa.sku)"
        Write-Host "  Branch:    $($swa.branch)"
        if ($swa.customDomains) {
            Write-Host "  Dominios:"
            $swa.customDomains | ForEach-Object { Write-Host "    - $_" }
        }
    }
    else {
        Write-Fail "No se pudo obtener estado de la Static Web App"
    }

    # Verificar que la pagina responde
    Write-Host ""
    try {
        $response = Invoke-WebRequest -Uri $URLS.FrontendPublic -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        Write-Ok "Frontend responde: HTTP $($response.StatusCode)"
    }
    catch {
        Write-Warn "Frontend no responde en $($URLS.FrontendPublic)"
    }
}

function Start-LocalServer {
    param([hashtable]$Secrets)

    if (-not (Test-Path $FLUTTER.BuildDir)) {
        Write-Fail "No hay build en $($FLUTTER.BuildDir). Ejecutar primero sin -Action local"
        exit 1
    }

    Write-Step "LOCAL" "Iniciando servidor local en puerto 8080..."
    Write-Host "  URL: http://localhost:8080"
    Write-Host "  Ctrl+C para detener"
    Write-Host ""

    Push-Location "$PSScriptRoot\$($FLUTTER.BuildDir)"
    try {
        python -m http.server 8080
    }
    finally {
        Pop-Location
    }
}

# ============================================================================
# MAIN
# ============================================================================

$startTime = Get-Date

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  TravelBox Peru Frontend - Azure Deploy" -ForegroundColor Cyan
Write-Host "  Accion: $Action | Entorno: $Environment" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

switch ($Action) {

    "status" {
        Test-AzureCli
        Test-AzureLogin
        Show-Status
    }

    "config-only" {
        Test-AzureCli
        Test-AzureLogin
        $secrets = Get-FrontendSecrets
        Write-Host ""
        Write-Host "  Secretos disponibles para build:" -ForegroundColor White
        foreach ($kv in $secrets.GetEnumerator()) {
            Write-Host "    $($kv.Key) = $($kv.Value.Substring(0, [Math]::Min(8, $kv.Value.Length)))..." -ForegroundColor DarkGray
        }
    }

    "build-only" {
        Test-FlutterSdk
        # Usar secrets vacios o de env vars locales
        $secrets = @{}
        foreach ($item in $KV_FRONTEND_SECRETS) {
            $envVal = [System.Environment]::GetEnvironmentVariable($item.Env)
            if ($envVal) { $secrets[$item.Env] = $envVal }
        }
        $buildPath = Build-Flutter -Secrets $secrets
        Write-Ok "Build listo en: $buildPath"
    }

    "local" {
        $secrets = @{}
        Start-LocalServer -Secrets $secrets
    }

    "deploy" {
        # Paso 1: Pre-requisitos
        Write-Step "PRE" "Verificando pre-requisitos..."
        Test-AzureCli
        Test-AzureLogin
        if (-not $SkipBuild) {
            Test-FlutterSdk
        }
        Write-Ok "Pre-requisitos OK"

        # Paso 2: Key Vault Secrets
        $secrets = Get-FrontendSecrets

        # Paso 3: Build Flutter
        if (-not $SkipBuild) {
            $buildPath = Build-Flutter -Secrets $secrets
        }
        else {
            $buildPath = Join-Path $PSScriptRoot $FLUTTER.BuildDir
            if (-not (Test-Path "$buildPath\index.html")) {
                Write-Fail "No hay build existente en $($FLUTTER.BuildDir). Ejecutar sin -SkipBuild"
                exit 1
            }
            Write-Ok "Usando build existente en $($FLUTTER.BuildDir)"
        }

        # Paso 4: Deploy
        Deploy-ToStaticWebApp -BuildPath $buildPath

        $elapsed = (Get-Date) - $startTime
        Write-Host ""
        Write-Host "========================================================" -ForegroundColor Green
        Write-Host "  DESPLIEGUE COMPLETADO" -ForegroundColor Green
        Write-Host "  Tiempo: $([math]::Round($elapsed.TotalMinutes, 1)) minutos" -ForegroundColor Green
        Write-Host "  URL: $($URLS.FrontendPublic)" -ForegroundColor Green
        Write-Host "========================================================" -ForegroundColor Green
    }
}
