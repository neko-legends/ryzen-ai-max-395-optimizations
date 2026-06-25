param(
    [string[]]$Case = @("hip-no-mtp-t28-ub1024"),
    [int]$Port = 8124,
    [int]$MaxTokens = 256,
    [int]$Runs = 1,
    [int]$Context = 262144,
    [double]$Temperature = 0.0,
    [int]$Seed = 1234,
    [string]$ModelPath = "",
    [string]$ModelPattern = "ornith-1.0-35b-Q4_K_M.gguf",
    [string[]]$SearchRoots = @(
        (Join-Path $HOME "Downloads"),
        (Join-Path $HOME ".cache\huggingface\hub\models--deepreinforce-ai--Ornith-1.0-35B-GGUF\snapshots")
    ),
    [string]$OutCsv = "",
    [string]$Prompt = "",
    [string]$PromptFile = "",
    [string]$PromptStyle = "default",
    [int]$TargetPromptTokens = 0,
    [string]$ServerPath = (Join-Path $HOME ".unsloth\llama.cpp\build\bin\Release\llama-server.exe"),
    [string]$ModelId = "ornith-1.0-35b-q4-k-m",
    [ValidateSet("on", "off", "auto")]
    [string]$Reasoning = "on",
    [ValidateRange(-1, 2147483647)]
    [int]$ReasoningBudget = -1,
    [string]$CacheTypeK = "f16",
    [string]$CacheTypeV = "f16",
    [int]$CacheRam = 0,
    [switch]$Mlock,
    [int]$RequestTimeoutSeconds = 3600,
    [int]$StartupTimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"

if (-not $OutCsv) {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutCsv = Join-Path $repoRoot "results\ornith-1.0-35b-gguf\ornith-1.0-35b-q4-k-m-$stamp.csv"
}

$benchScript = Join-Path $PSScriptRoot "bench-ornith-1.0-35b-q5-k-m.ps1"
$forward = @{
    Case = $Case
    Port = $Port
    MaxTokens = $MaxTokens
    Runs = $Runs
    Context = $Context
    Temperature = $Temperature
    Seed = $Seed
    ModelPattern = $ModelPattern
    SearchRoots = $SearchRoots
    OutCsv = $OutCsv
    Prompt = $Prompt
    PromptFile = $PromptFile
    PromptStyle = $PromptStyle
    TargetPromptTokens = $TargetPromptTokens
    ServerPath = $ServerPath
    ModelId = $ModelId
    Reasoning = $Reasoning
    ReasoningBudget = $ReasoningBudget
    CacheTypeK = $CacheTypeK
    CacheTypeV = $CacheTypeV
    CacheRam = $CacheRam
    RequestTimeoutSeconds = $RequestTimeoutSeconds
    StartupTimeoutSeconds = $StartupTimeoutSeconds
}

if ($ModelPath) {
    $forward.ModelPath = $ModelPath
}

if ($Mlock) {
    $forward.Mlock = $true
}

& $benchScript @forward
