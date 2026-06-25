param(
    [int]$Port = 8001,
    [int]$Context = 262144,
    [ValidateRange(1, 6)]
    [int]$DraftN = 3,
    [int]$Threads = 28,
    [int]$ThreadsBatch = 28,
    [int]$BatchSize = 2048,
    [int]$UBatchSize = 1024,
    [string]$ModelPath = "",
    [string[]]$ModelPatterns = @("Qwen3.6-35B-A3B-MXFP4_MOE.gguf"),
    [string[]]$SearchRoots = @(
        (Join-Path $HOME "Downloads"),
        (Join-Path $HOME ".cache\huggingface\hub\models--unsloth--Qwen3.6-35B-A3B-MTP-GGUF\snapshots")
    ),
    [string]$ServerPath = (Join-Path $HOME ".unsloth\llama.cpp\build\bin\Release\llama-server.exe"),
    [ValidateSet("on", "off", "auto")]
    [string]$Reasoning = "off",
    [ValidateRange(-1, 2147483647)]
    [int]$ReasoningBudget = -1,
    [switch]$KvUnified,
    [switch]$Mlock
)

$ErrorActionPreference = "Stop"

function Resolve-QwenMxfp4Model {
    if ($ModelPath) {
        return (Resolve-Path -LiteralPath $ModelPath).Path
    }

    $candidates = @()
    foreach ($root in $SearchRoots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        foreach ($pattern in $ModelPatterns) {
            $candidates += Get-ChildItem -LiteralPath $root -Recurse -Filter $pattern -ErrorAction SilentlyContinue
        }
    }

    $model = $candidates |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $model) {
        $patterns = $ModelPatterns -join ", "
        $roots = $SearchRoots -join ", "
        throw "Could not find $patterns under: $roots. Pass -ModelPath C:\path\to\Qwen3.6-35B-A3B-MXFP4_MOE.gguf."
    }

    $model.FullName
}

if (-not (Test-Path -LiteralPath $ServerPath)) {
    throw "llama-server.exe was not found at $ServerPath"
}

$ResolvedModelPath = Resolve-QwenMxfp4Model

Write-Host "Starting Qwen3.6 35B-A3B MXFP4_MOE MTP on http://127.0.0.1:$Port/v1"
Write-Host "Model: $ResolvedModelPath"
Write-Host "Context: $Context, DraftN: $DraftN, Threads: $Threads, UBatch: $UBatchSize, Reasoning: $Reasoning"
Write-Host "KV unified: $([bool]$KvUnified), Metrics: on, Mlock: $([bool]$Mlock)"

$llamaArgs = @(
    "-m", $ResolvedModelPath,
    "--host", "127.0.0.1",
    "--port", "$Port",
    "-c", "$Context",
    "--parallel", "1",
    "--flash-attn", "on",
    "--no-context-shift",
    "-ngl", "999",
    "--metrics",
    "--jinja",
    "--reasoning", $Reasoning,
    "--temp", "0.6",
    "--top-p", "0.95",
    "--top-k", "20",
    "--min-p", "0.00",
    "--cache-type-k", "f16",
    "--cache-type-v", "f16",
    "--spec-draft-type-k", "f16",
    "--spec-draft-type-v", "f16",
    "--spec-type", "draft-mtp",
    "--spec-draft-n-max", "$DraftN",
    "--spec-draft-ngl", "999",
    "--batch-size", "$BatchSize",
    "--ubatch-size", "$UBatchSize",
    "--threads", "$Threads",
    "--threads-batch", "$ThreadsBatch",
    "--poll", "100",
    "--poll-batch", "1",
    "--no-mmap",
    "--no-mmproj",
    "--cache-ram", "0",
    "--ctx-checkpoints", "0",
    "--no-cache-prompt"
)

if ($KvUnified) {
    $llamaArgs += "--kv-unified"
}

if ($Mlock) {
    $llamaArgs += "--mlock"
}

if ($Reasoning -ne "off") {
    $llamaArgs += @("--reasoning-budget", "$ReasoningBudget")
}

& $ServerPath @llamaArgs
