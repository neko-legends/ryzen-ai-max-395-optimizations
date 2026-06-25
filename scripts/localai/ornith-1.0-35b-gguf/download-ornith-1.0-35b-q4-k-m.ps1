param(
    [string]$RepoId = "deepreinforce-ai/Ornith-1.0-35B-GGUF",
    [string]$FileName = "ornith-1.0-35b-Q4_K_M.gguf",
    [string]$LocalDir = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$downloadScript = Join-Path $PSScriptRoot "download-ornith-1.0-35b-q5-k-m.ps1"
$forward = @{
    RepoId = $RepoId
    FileName = $FileName
}

if ($LocalDir) {
    $forward.LocalDir = $LocalDir
}

if ($Force) {
    $forward.Force = $true
}

& $downloadScript @forward
