param(
    [string]$BaseUrl = "http://127.0.0.1:8001/v1",
    [string]$Model = "local",
    [int]$ContextLength = 262144,
    [string]$Provider = "custom"
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
Write-Host "Provider: $Provider"
Write-Host "Base URL: $BaseUrl"
Write-Host "Model: $Model"
Write-Host "Context length: $ContextLength"
Write-Host "Backup: $BackupPath"
Write-Host ""
Write-Host "Start the model server before opening Hermes Desktop or starting a Hermes chat."
