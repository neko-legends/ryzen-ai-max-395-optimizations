param(
    [string]$BaseUrl = "http://127.0.0.1:8001/v1",
    [string]$Model = "local",
    [int]$ContextLength = 262144,
    [string]$Provider = "custom",
    [string]$Name = "Qwen3.6 35B-A3B MTP 262K"
)

$ErrorActionPreference = "Stop"

$HermesHome = Join-Path $env:LOCALAPPDATA "hermes"
$ConfigPath = Join-Path $HermesHome "config.yaml"
$HermesPython = Join-Path $HermesHome "hermes-agent\venv\Scripts\python.exe"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Hermes config was not found at $ConfigPath"
}

if (-not (Test-Path -LiteralPath $HermesPython)) {
    throw "Hermes Python was not found at $HermesPython"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupPath = "$ConfigPath.bak-qwen-local-$timestamp"
Copy-Item -LiteralPath $ConfigPath -Destination $BackupPath -Force

$registerCode = @"
from hermes_cli.main import _save_custom_provider

_save_custom_provider(
    '$BaseUrl',
    model='$Model',
    context_length=$ContextLength,
    name='$Name',
    api_mode='chat_completions',
)
"@

& $HermesPython -c $registerCode
if ($LASTEXITCODE -ne 0) {
    throw "Hermes custom provider registration failed"
}

function Update-SavedProviderName {
    param(
        [string]$Path,
        [string]$ExpectedBaseUrl,
        [string]$ExpectedModel,
        [string]$ExpectedName
    )

    $text = Get-Content -LiteralPath $Path -Raw
    $pattern = "(?ms)(- name: ).*?(\r?\n\s+base_url: $([regex]::Escape($ExpectedBaseUrl))\r?\n\s+model: $([regex]::Escape($ExpectedModel)))"
    $match = [regex]::Match($text, $pattern)
    if (-not $match.Success) {
        return
    }

    $replacement = $match.Groups[1].Value + $ExpectedName + $match.Groups[2].Value
    $updated = $text.Remove($match.Index, $match.Length).Insert($match.Index, $replacement)
    if ($updated -ne $text) {
        Set-Content -LiteralPath $Path -Value $updated -NoNewline
    }
}

Update-SavedProviderName -Path $ConfigPath -ExpectedBaseUrl $BaseUrl -ExpectedModel $Model -ExpectedName $Name

function Set-HermesConfig {
    param(
        [string]$Key,
        [string]$Value
    )

    & $HermesPython -m hermes_cli.main config set $Key $Value
    if ($LASTEXITCODE -ne 0) {
        throw "Hermes config set failed for $Key"
    }
}

Set-HermesConfig "model.provider" $Provider
Set-HermesConfig "model.base_url" $BaseUrl
Set-HermesConfig "model.default" $Model
Set-HermesConfig "model.context_length" "$ContextLength"
Set-HermesConfig "model.api_mode" "chat_completions"

Write-Host ""
Write-Host "Hermes is configured for the local OpenAI-compatible Qwen endpoint."
Write-Host "Name: $Name"
Write-Host "Provider: $Provider"
Write-Host "Base URL: $BaseUrl"
Write-Host "Model: $Model"
Write-Host "Context length: $ContextLength"
Write-Host "Backup: $BackupPath"
Write-Host ""
Write-Host "Start the model server before opening Hermes Desktop or starting a Hermes chat."
