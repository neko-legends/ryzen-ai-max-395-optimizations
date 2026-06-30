param(
    [string]$BaseUrl = "http://127.0.0.1:8004/v1",
    [string]$ProviderName = "Qwopus3.6 35B-A3B Coder MTP Q5_K_M 262K",
    [switch]$ConfigureHermesDefault,
    [switch]$ForceDownload
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..\..")
$downloadScript = Join-Path $scriptDir "download-qwopus36-35b-a3b-coder-mtp-q5-k-m.ps1"
$addProviderScript = Join-Path $repoRoot "scripts\hermes\add-hermes-qwen-custom-provider.ps1"
$configureProviderScript = Join-Path $repoRoot "scripts\hermes\configure-hermes-qwen-local-provider.ps1"

if ($ForceDownload) {
    & $downloadScript -Force
} else {
    & $downloadScript
}

if ($ConfigureHermesDefault) {
    & $configureProviderScript -BaseUrl $BaseUrl -Name $ProviderName
} else {
    & $addProviderScript -BaseUrl $BaseUrl -Name $ProviderName
}

Write-Host ""
Write-Host "Qwopus install complete."
Write-Host "Hermes provider: $ProviderName"
Write-Host "Endpoint: $BaseUrl"
Write-Host "Start server with:"
Write-Host "  scripts\localai\qwopus36-35b-a3b-coder-mtp-gguf\start-qwopus36-35b-a3b-coder-mtp-q5-k-m-262k.bat"
