param(
    [string]$ProjectId = "",
    [string]$Region = "us-central1",
    [string]$BackendServiceName = "travelbox-backend-prod",
    [string]$FrontendServiceName = "travelbox-frontend-prod",
    [string]$BackendVpcConnector = "",
    [ValidateSet("private-ranges-only", "all-traffic")]
    [string]$BackendVpcEgress = "all-traffic",
    [int]$BackendTimeoutSeconds = 300,
    [string]$BackendMemory = "1Gi",
    [string]$BackendCpu = "1",
    [int]$BackendConcurrency = 40,
    [int]$BackendMinInstances = 0,
    [int]$BackendMaxInstances = 12,
    [string]$AzureKeyVaultName = "kvtravelboxpe",
    [switch]$SkipBackendCompile,
    [switch]$SkipBackendDeploy,
    [switch]$SkipFrontendBuild,
    [switch]$SkipFrontendDeploy,
    [switch]$NoExecute
)

$ErrorActionPreference = "Stop"

$appRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $appRoot
$backendRoot = Join-Path $workspaceRoot "TravelBox_Peru_Backend"
$azureKvLoaderPath = Join-Path $workspaceRoot "tools\load_azure_kv_env.ps1"
$backendProdEnvFile = Join-Path $workspaceRoot "cloudrun-backend-env.prod.yaml"

function Write-Step {
    param(
        [int]$Percent,
        [string]$Status
    )
    Write-Progress -Id 2 -Activity "TravelBox production deploy" -Status $Status -PercentComplete $Percent
    Write-Host ("[{0,3}%] {1}" -f $Percent, $Status)
}

function Resolve-GcloudPath {
    $gcloudCmd = Get-Command gcloud -ErrorAction SilentlyContinue
    if ($null -ne $gcloudCmd -and -not [string]::IsNullOrWhiteSpace($gcloudCmd.Source)) {
        return $gcloudCmd.Source
    }

    $fallback = Join-Path $workspaceRoot "tools\gcloud\google-cloud-sdk\bin\gcloud.cmd"
    if (Test-Path $fallback) {
        return $fallback
    }

    throw "No se encontro gcloud CLI. Instala gcloud o agrega su ruta al PATH."
}

function Ensure-GcloudServicesEnabled {
    param(
        [string]$GcloudPath,
        [string]$Project,
        [string[]]$Services
    )
    if ($Services.Count -eq 0) {
        return
    }
    & $GcloudPath services enable @Services --project $Project --quiet
    if ($LASTEXITCODE -ne 0) {
        throw ("No se pudieron habilitar APIs requeridas: {0}" -f ($Services -join ", "))
    }
}

function Get-CloudRunServiceUrl {
    param(
        [string]$GcloudPath,
        [string]$ServiceName,
        [string]$Project,
        [string]$CloudRegion
    )
    try {
        $url = (& $GcloudPath run services describe $ServiceName `
            --platform managed `
            --region $CloudRegion `
            --project $Project `
            --format "value(status.url)" 2>$null).Trim()
        if ([string]::IsNullOrWhiteSpace($url)) {
            return $null
        }
        return $url
    } catch {
        return $null
    }
}

function Get-NewLogLines {
    param(
        [string]$Path,
        [int]$LastLineRead = 0
    )
    if (-not (Test-Path $Path)) {
        return @{
            Lines = @()
            LastLineRead = $LastLineRead
        }
    }

    $lines = @(Get-Content -Path $Path)
    if ($lines.Count -le $LastLineRead) {
        return @{
            Lines = @()
            LastLineRead = $lines.Count
        }
    }

    $newLines = @($lines[$LastLineRead..($lines.Count - 1)])
    return @{
        Lines = $newLines
        LastLineRead = $lines.Count
    }
}

function Invoke-GcloudWithFrontendUploadProgress {
    param(
        [string]$GcloudPath,
        [string[]]$Arguments,
        [int]$MainProgressId = 2,
        [int]$UploadProgressId = 22,
        [int]$HeartbeatSeconds = 4,
        [int]$EstimatedUploadSeconds = 240
    )

    $stdoutLog = Join-Path $appRoot ("tmp.frontend.deploy.stdout.{0}.log" -f ([Guid]::NewGuid().ToString("N")))
    $stderrLog = Join-Path $appRoot ("tmp.frontend.deploy.stderr.{0}.log" -f ([Guid]::NewGuid().ToString("N")))

    $stdoutCursor = 0
    $stderrCursor = 0
    $uploadDetected = $false
    $uploadCompleted = $false
    $uploadStartedAt = $null
    $explicitUploadPercent = -1
    $lastPrintedPercent = -1
    $lastHeartbeatAt = Get-Date

    try {
        Write-Progress -Id $UploadProgressId -ParentId $MainProgressId -Activity "Upload frontend a Cloud Run" -Status "Esperando inicio de upload..." -PercentComplete 0

        $process = Start-Process `
            -FilePath $GcloudPath `
            -ArgumentList $Arguments `
            -PassThru `
            -NoNewWindow `
            -RedirectStandardOutput $stdoutLog `
            -RedirectStandardError $stderrLog

        while (-not $process.HasExited) {
            Start-Sleep -Milliseconds 900

            $stdoutChunk = Get-NewLogLines -Path $stdoutLog -LastLineRead $stdoutCursor
            $stdoutCursor = $stdoutChunk.LastLineRead
            foreach ($line in $stdoutChunk.Lines) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-Host $line
                }
                $lineText = if ($null -eq $line) { "" } else { $line.ToString().Trim() }
                if ([string]::IsNullOrWhiteSpace($lineText)) {
                    continue
                }
                $lineLower = $lineText.ToLowerInvariant()

                if (-not $uploadDetected -and $lineLower -match "upload") {
                    $uploadDetected = $true
                    $uploadStartedAt = Get-Date
                    Write-Host "[FRONT-UPLOAD] Inicio de subida detectado."
                }

                if (($uploadDetected -or $lineLower -match "upload") -and $lineText -match "(?<pct>\d{1,3})%") {
                    $candidate = [int]$matches["pct"]
                    if ($candidate -ge 0 -and $candidate -le 100) {
                        $explicitUploadPercent = $candidate
                    }
                }

                if ($uploadDetected -and -not $uploadCompleted -and ($lineLower -match "building container" -or $lineLower -match "build logs are available" -or $lineLower -match "creating revision" -or $lineLower -match "routing traffic")) {
                    $uploadCompleted = $true
                    Write-Progress -Id $UploadProgressId -ParentId $MainProgressId -Activity "Upload frontend a Cloud Run" -Status "Subida completada (100%)." -PercentComplete 100
                    Write-Host "[FRONT-UPLOAD] 100% subida completada."
                }
            }

            $stderrChunk = Get-NewLogLines -Path $stderrLog -LastLineRead $stderrCursor
            $stderrCursor = $stderrChunk.LastLineRead
            foreach ($line in $stderrChunk.Lines) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-Host $line
                }
                $lineText = if ($null -eq $line) { "" } else { $line.ToString().Trim() }
                if ([string]::IsNullOrWhiteSpace($lineText)) {
                    continue
                }
                $lineLower = $lineText.ToLowerInvariant()
                if (-not $uploadDetected -and $lineLower -match "upload") {
                    $uploadDetected = $true
                    $uploadStartedAt = Get-Date
                    Write-Host "[FRONT-UPLOAD] Inicio de subida detectado."
                }
                if (($uploadDetected -or $lineLower -match "upload") -and $lineText -match "(?<pct>\d{1,3})%") {
                    $candidate = [int]$matches["pct"]
                    if ($candidate -ge 0 -and $candidate -le 100) {
                        $explicitUploadPercent = $candidate
                    }
                }
            }

            if ($uploadDetected -and -not $uploadCompleted) {
                $displayPercent = if ($explicitUploadPercent -ge 0) {
                    $explicitUploadPercent
                } else {
                    $elapsedSeconds = ((Get-Date) - $uploadStartedAt).TotalSeconds
                    [Math]::Min(95, [Math]::Max(1, [int][Math]::Floor(($elapsedSeconds / [Math]::Max(30, $EstimatedUploadSeconds)) * 95)))
                }
                $suffix = if ($explicitUploadPercent -ge 0) { "" } else { " (estimado)" }

                Write-Progress -Id $UploadProgressId -ParentId $MainProgressId -Activity "Upload frontend a Cloud Run" -Status ("Subiendo: {0}%{1}" -f $displayPercent, $suffix) -PercentComplete $displayPercent
                $secondsSinceHeartbeat = ((Get-Date) - $lastHeartbeatAt).TotalSeconds
                if ($displayPercent -ne $lastPrintedPercent -or $secondsSinceHeartbeat -ge $HeartbeatSeconds) {
                    Write-Host ("[FRONT-UPLOAD] {0}%{1}" -f $displayPercent, $suffix)
                    $lastPrintedPercent = $displayPercent
                    $lastHeartbeatAt = Get-Date
                }
            }
        }

        $stdoutTail = Get-NewLogLines -Path $stdoutLog -LastLineRead $stdoutCursor
        foreach ($line in $stdoutTail.Lines) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                Write-Host $line
            }
        }
        $stderrTail = Get-NewLogLines -Path $stderrLog -LastLineRead $stderrCursor
        foreach ($line in $stderrTail.Lines) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                Write-Host $line
            }
        }

        if ($process.ExitCode -ne 0) {
            throw ("gcloud frontend deploy fallo con exit code {0}." -f $process.ExitCode)
        }

        if ($uploadDetected -and -not $uploadCompleted) {
            Write-Progress -Id $UploadProgressId -ParentId $MainProgressId -Activity "Upload frontend a Cloud Run" -Status "Subida completada (100%)." -PercentComplete 100
            Write-Host "[FRONT-UPLOAD] 100% subida completada."
        }
    } finally {
        Write-Progress -Id $UploadProgressId -Activity "Upload frontend a Cloud Run" -Completed
        if (Test-Path $stdoutLog) {
            Remove-Item -Path $stdoutLog -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $stderrLog) {
            Remove-Item -Path $stderrLog -Force -ErrorAction SilentlyContinue
        }
    }
}

if (-not (Test-Path $backendProdEnvFile)) {
    throw "No se encontro env file prod: $backendProdEnvFile"
}

$kvResult = $null
Write-Step -Percent 5 -Status "Cargando secretos desde Azure Key Vault al proceso..."
if (Test-Path $azureKvLoaderPath) {
    try {
        $kvResult = . $azureKvLoaderPath -VaultName $AzureKeyVaultName -Quiet
        if ($kvResult.loadedCount -gt 0) {
            Write-Host ("Key Vault '{0}': {1} variables cargadas." -f $AzureKeyVaultName, $kvResult.loadedCount)
        }
        if ($kvResult.pendingCount -gt 0) {
            Write-Warning ("Secrets pendientes en vault: {0}" -f ($kvResult.pendingSecretNames -join ", "))
        }
    } catch {
        Write-Warning ("No se pudo cargar Key Vault '{0}': {1}" -f $AzureKeyVaultName, $_.Exception.Message)
    }
}

Write-Step -Percent 12 -Status "Resolviendo gcloud project y validaciones previas..."
$gcloud = Resolve-GcloudPath
if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    $ProjectId = (& $gcloud config get-value project --quiet 2>$null).Trim()
}
if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    throw "No se detecto ProjectId. Pasa -ProjectId o ejecuta gcloud config set project <id>."
}

Write-Step -Percent 18 -Status "Habilitando APIs requeridas para deploy..."
$requiredApis = @(
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "vpcaccess.googleapis.com"
)
if (-not $NoExecute) {
    Ensure-GcloudServicesEnabled -GcloudPath $gcloud -Project $ProjectId -Services $requiredApis
} else {
    Write-Host ("NoExecute: {0} services enable {1} --project {2} --quiet" -f $gcloud, ($requiredApis -join " "), $ProjectId)
}

$azureClientIdRaw = [Environment]::GetEnvironmentVariable("AZURE_CLIENT_ID")
$azureClientSecretRaw = [Environment]::GetEnvironmentVariable("AZURE_CLIENT_SECRET")
$azureTenantIdRaw = [Environment]::GetEnvironmentVariable("AZURE_TENANT_ID")
$azureClientId = if ($null -eq $azureClientIdRaw) { "" } else { $azureClientIdRaw.Trim() }
$azureClientSecret = if ($null -eq $azureClientSecretRaw) { "" } else { $azureClientSecretRaw.Trim() }
$azureTenantId = if ($null -eq $azureTenantIdRaw) { "" } else { $azureTenantIdRaw.Trim() }

if (-not $SkipBackendDeploy) {
    if ($null -eq $kvResult) {
        throw "No se pudo cargar Azure Key Vault. El deploy prod requiere secretos desde Key Vault."
    }
    $loadedFromVault = @($kvResult.loadedEnvNames)
    $requiredKvEnvNames = @("AZURE_CLIENT_ID", "AZURE_CLIENT_SECRET", "AZURE_TENANT_ID")
    foreach ($requiredName in $requiredKvEnvNames) {
        if ($loadedFromVault -notcontains $requiredName) {
            throw ("Falta '{0}' desde Key Vault. Crea/activa secretos tbx-azure-client-id, tbx-azure-client-secret y tbx-azure-tenant-id en '{1}'." -f $requiredName, $AzureKeyVaultName)
        }
    }
    if ([string]::IsNullOrWhiteSpace($azureClientId) -or [string]::IsNullOrWhiteSpace($azureClientSecret) -or [string]::IsNullOrWhiteSpace($azureTenantId)) {
        throw "Azure SP incompleto tras cargar Key Vault. Verifica secretos tbx-azure-client-id / tbx-azure-client-secret / tbx-azure-tenant-id."
    }
}

if (-not $SkipBackendCompile) {
    Write-Step -Percent 25 -Status "Compilando backend (smoke check sin tests)..."
    if ($NoExecute) {
        Write-Host ("NoExecute: .\mvnw.cmd -DskipTests compile en {0}" -f $backendRoot)
    } else {
        Push-Location $backendRoot
        try {
            & .\mvnw.cmd -DskipTests compile
            if ($LASTEXITCODE -ne 0) {
                throw "mvnw compile fallo."
            }
        } finally {
            Pop-Location
        }
    }
} else {
    Write-Step -Percent 25 -Status "Salto compilacion backend por parametro."
}

if (-not $SkipBackendDeploy) {
    Write-Step -Percent 45 -Status "Desplegando backend prod en Cloud Run..."
    $backendEnvFileForDeploy = $backendProdEnvFile
    $tempBackendEnvFile = $null
    try {
        $tempBackendEnvFile = Join-Path $appRoot ("tmp.cloudrun-backend-env.prod.{0}.yaml" -f ([Guid]::NewGuid().ToString("N")))
        Copy-Item -Path $backendProdEnvFile -Destination $tempBackendEnvFile -Force

        $content = Get-Content -Raw $tempBackendEnvFile
        $yamlSafeClientId = $azureClientId -replace "'", "''"
        $yamlSafeClientSecret = $azureClientSecret -replace "'", "''"
        $yamlSafeTenantId = $azureTenantId -replace "'", "''"

        $yamlUpdates = @(
            @{ Key = "AZURE_CLIENT_ID"; Value = "AZURE_CLIENT_ID: '$yamlSafeClientId'" },
            @{ Key = "AZURE_CLIENT_SECRET"; Value = "AZURE_CLIENT_SECRET: '$yamlSafeClientSecret'" },
            @{ Key = "AZURE_TENANT_ID"; Value = "AZURE_TENANT_ID: '$yamlSafeTenantId'" }
        )

        foreach ($item in $yamlUpdates) {
            if ($content -match ("(?m)^\s*" + [regex]::Escape($item.Key) + "\s*:")) {
                $content = [regex]::Replace(
                    $content,
                    ("(?m)^\s*" + [regex]::Escape($item.Key) + "\s*:\s*.*$"),
                    $item.Value
                )
            } else {
                $content = $content.TrimEnd() + [Environment]::NewLine + $item.Value + [Environment]::NewLine
            }
        }

        Set-Content -Path $tempBackendEnvFile -Value $content -Encoding UTF8
        $backendEnvFileForDeploy = $tempBackendEnvFile

        $backendDeployArgs = @(
            "run", "deploy", $BackendServiceName,
            "--source", $backendRoot,
            "--project", $ProjectId,
            "--region", $Region,
            "--env-vars-file", $backendEnvFileForDeploy,
            "--platform", "managed",
            "--allow-unauthenticated",
            "--port", "8080",
            "--memory", $BackendMemory,
            "--cpu", $BackendCpu,
            "--concurrency", "$BackendConcurrency",
            "--min-instances", "$BackendMinInstances",
            "--max-instances", "$BackendMaxInstances",
            "--timeout", "$BackendTimeoutSeconds",
            "--quiet"
        )
        if (-not [string]::IsNullOrWhiteSpace($BackendVpcConnector)) {
            $backendDeployArgs += @("--vpc-connector", $BackendVpcConnector, "--vpc-egress", $BackendVpcEgress)
        }

        if ($NoExecute) {
            Write-Host ("NoExecute: {0} {1}" -f $gcloud, ($backendDeployArgs -join " "))
        } else {
            & $gcloud @backendDeployArgs
            if ($LASTEXITCODE -ne 0) {
                throw "Deploy backend fallo."
            }
        }
    } finally {
        if ($null -ne $tempBackendEnvFile -and (Test-Path $tempBackendEnvFile)) {
            Remove-Item -Path $tempBackendEnvFile -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Step -Percent 45 -Status "Salto deploy backend por parametro."
}

Write-Step -Percent 58 -Status "Leyendo URL activa del backend..."
$backendUrl = Get-CloudRunServiceUrl -GcloudPath $gcloud -ServiceName $BackendServiceName -Project $ProjectId -CloudRegion $Region
if ([string]::IsNullOrWhiteSpace($backendUrl) -and -not $NoExecute -and -not $SkipFrontendBuild) {
    throw "No se pudo resolver URL del backend ($BackendServiceName)."
}

$apiBaseUrl = if ([string]::IsNullOrWhiteSpace($backendUrl)) {
    "https://REEMPLAZAR_BACKEND_URL/api/v1"
} else {
    "$backendUrl/api/v1"
}

$frontendDartDefines = @(
    "--dart-define=APP_ENV=prod",
    "--dart-define=USE_MOCK_FALLBACK=false",
    "--dart-define=API_BASE_URL=$apiBaseUrl"
)

$cashOnlyFlag = [Environment]::GetEnvironmentVariable("APP_PAYMENTS_FORCE_CASH_ONLY")
if ([string]::IsNullOrWhiteSpace($cashOnlyFlag)) {
    $cashOnlyFlag = "false"
}
$frontendDartDefines += "--dart-define=FORCE_CASH_PAYMENTS_ONLY=$cashOnlyFlag"

$firebaseDefineNames = @(
    "FIREBASE_API_KEY",
    "FIREBASE_PROJECT_ID",
    "FIREBASE_MESSAGING_SENDER_ID",
    "FIREBASE_STORAGE_BUCKET",
    "FIREBASE_AUTH_DOMAIN",
    "FIREBASE_GOOGLE_SERVER_CLIENT_ID",
    "FIREBASE_IOS_BUNDLE_ID",
    "FIREBASE_ANDROID_APP_ID",
    "FIREBASE_IOS_APP_ID",
    "FIREBASE_WEB_APP_ID",
    "FIREBASE_FACEBOOK_ENABLED",
    "FIREBASE_STORAGE_UPLOADS_ENABLED"
)
$requiredFirebaseDefineNames = @(
    "FIREBASE_API_KEY",
    "FIREBASE_PROJECT_ID",
    "FIREBASE_MESSAGING_SENDER_ID"
)
$firebaseLoadedDefines = @()
$firebaseMissingRequired = @()

foreach ($defineName in $firebaseDefineNames) {
    $defineValue = [Environment]::GetEnvironmentVariable($defineName)
    if (-not [string]::IsNullOrWhiteSpace($defineValue)) {
        $frontendDartDefines += "--dart-define=$defineName=$defineValue"
        $firebaseLoadedDefines += $defineName
    } elseif ($requiredFirebaseDefineNames -contains $defineName) {
        $firebaseMissingRequired += $defineName
    }
}

if (-not $SkipFrontendBuild -and $firebaseMissingRequired.Count -gt 0) {
    throw ("Faltan FIREBASE_* requeridos para build prod: {0}" -f ($firebaseMissingRequired -join ", "))
}

if ($null -ne $kvResult -and -not $SkipFrontendBuild) {
    $loadedFromVault = @($kvResult.loadedEnvNames)
    $missingInVault = @()
    foreach ($requiredFirebaseName in $requiredFirebaseDefineNames) {
        if ($loadedFromVault -notcontains $requiredFirebaseName) {
            $missingInVault += $requiredFirebaseName
        }
    }
    if ($missingInVault.Count -gt 0) {
        throw ("Faltan secrets en Key Vault para frontend prod: {0}" -f ($missingInVault -join ", "))
    }
}

if (-not $SkipFrontendBuild) {
    Write-Step -Percent 70 -Status "Compilando frontend web release..."
    if ($NoExecute) {
        Write-Host ("NoExecute: flutter build web --release {0}" -f ($frontendDartDefines -join " "))
    } else {
        Push-Location $appRoot
        try {
            & flutter build web --release @frontendDartDefines
            if ($LASTEXITCODE -ne 0) {
                throw "flutter build web fallo."
            }
        } finally {
            Pop-Location
        }
    }
} else {
    Write-Step -Percent 70 -Status "Salto build frontend por parametro."
}

if (-not $SkipFrontendDeploy) {
    Write-Step -Percent 88 -Status "Desplegando frontend prod en Cloud Run..."
    $frontendDeployArgs = @(
        "run", "deploy", $FrontendServiceName,
        "--source", $appRoot,
        "--project", $ProjectId,
        "--region", $Region,
        "--platform", "managed",
        "--allow-unauthenticated",
        "--port", "8080",
        "--quiet"
    )
    if ($NoExecute) {
        Write-Host ("NoExecute: {0} {1}" -f $gcloud, ($frontendDeployArgs -join " "))
    } else {
        Invoke-GcloudWithFrontendUploadProgress -GcloudPath $gcloud -Arguments $frontendDeployArgs -MainProgressId 2 -UploadProgressId 22
    }
} else {
    Write-Step -Percent 88 -Status "Salto deploy frontend por parametro."
}

$frontendUrl = Get-CloudRunServiceUrl -GcloudPath $gcloud -ServiceName $FrontendServiceName -Project $ProjectId -CloudRegion $Region
Write-Step -Percent 100 -Status "Deploy finalizado."
Write-Progress -Id 2 -Activity "TravelBox production deploy" -Completed

Write-Host ""
Write-Host "Resumen despliegue produccion"
Write-Host (" - Project ID:  {0}" -f $ProjectId)
Write-Host (" - Region:      {0}" -f $Region)
Write-Host (" - Backend:     {0}" -f ($(if ($backendUrl) { $backendUrl } else { "no-resuelto" })))
Write-Host (" - API Base:    {0}" -f $apiBaseUrl)
Write-Host (" - Frontend:    {0}" -f ($(if ($frontendUrl) { $frontendUrl } else { "no-resuelto" })))
Write-Host (" - Key Vault:   https://{0}.vault.azure.net/" -f $AzureKeyVaultName)
if ($NoExecute) {
    Write-Host ""
    Write-Host "Modo NoExecute activo: no se aplicaron cambios remotos."
}
