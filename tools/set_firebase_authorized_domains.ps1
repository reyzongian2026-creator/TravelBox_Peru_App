param(
    [string]$ProjectId = "travelboxperu-f96ee",
    [string[]]$Domains = @("travelbox-frontend-prod-otpbbcgoeq-uc.a.run.app"),
    [string]$GcloudPath = "C:\Users\GianLH\Desktop\PROYECTI\tools\gcloud\google-cloud-sdk\bin\gcloud.cmd"
)

$ErrorActionPreference = "Stop"
try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
} catch {
}

function Test-Blank([string]$value) {
    return [string]::IsNullOrWhiteSpace($value)
}

function Get-AccessToken {
    param(
        [string]$CliPath
    )
    if (-not (Test-Path $CliPath)) {
        throw "No se encontro gcloud en: $CliPath"
    }
    $token = (& $CliPath auth print-access-token).Trim()
    if (Test-Blank $token) {
        throw "No se pudo obtener access token de gcloud."
    }
    return $token
}

function Read-ErrorBody {
    param(
        [System.Exception]$Exception
    )
    $response = $Exception.Response
    if ($null -eq $response) {
        return $Exception.Message
    }
    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
    return $reader.ReadToEnd()
}

function Invoke-IdentityToolkit {
    param(
        [string]$Method,
        [string]$Uri,
        [string]$Token,
        [string]$QuotaProject,
        [hashtable]$Body
    )
    $headers = @{
        Authorization = "Bearer $Token"
        "Content-Type" = "application/json"
    }
    if (-not (Test-Blank $QuotaProject)) {
        $headers["x-goog-user-project"] = $QuotaProject
    }
    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers
        }
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 10)
    } catch {
        $errorBody = Read-ErrorBody -Exception $_.Exception
        throw "Identity Toolkit error ($Method $Uri): $errorBody"
    }
}

if ($null -eq $Domains -or $Domains.Count -eq 0) {
    throw "Debes enviar al menos un dominio en -Domains."
}

$token = Get-AccessToken -CliPath $GcloudPath
$configUri = "https://identitytoolkit.googleapis.com/admin/v2/projects/$ProjectId/config"
$currentConfig = Invoke-IdentityToolkit -Method "GET" -Uri $configUri -Token $token -QuotaProject $ProjectId -Body $null

$merged = @()
if ($currentConfig.authorizedDomains) {
    $merged += $currentConfig.authorizedDomains
}
$merged += $Domains
$merged = $merged |
    ForEach-Object { $_.Trim().ToLowerInvariant() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Sort-Object -Unique

$patchUri = "https://identitytoolkit.googleapis.com/admin/v2/projects/$ProjectId/config?updateMask=authorizedDomains"
$payload = @{
    authorizedDomains = $merged
}
Invoke-IdentityToolkit -Method "PATCH" -Uri $patchUri -Token $token -QuotaProject $ProjectId -Body $payload | Out-Null

$updatedConfig = Invoke-IdentityToolkit -Method "GET" -Uri $configUri -Token $token -QuotaProject $ProjectId -Body $null
Write-Host "Dominios autorizados actualizados:"
$updatedConfig.authorizedDomains | Sort-Object | ForEach-Object { Write-Host " - $_" }
