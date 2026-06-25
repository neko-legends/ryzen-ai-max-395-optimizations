param(
    [int]$Port = 8001,
    [int]$Context = 262144,
    [ValidateRange(1, 6)]
    [int]$DraftN = 2,
    [string]$ModelPath = "",
    [string]$ModelPattern = "Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf",
    [string]$SnapshotRoot = (Join-Path $HOME ".cache\huggingface\hub\models--unsloth--Qwen3.6-35B-A3B-MTP-GGUF\snapshots"),
    [string]$ServerPath = (Join-Path $HOME ".unsloth\llama.cpp\build\bin\Release\llama-server.exe"),
    [ValidateSet("on", "off", "auto")]
    [string]$Reasoning = "off"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ServerPath)) {
    throw "llama-server.exe was not found at $ServerPath"
}

if ($ModelPath) {
    $ResolvedModelPath = (Resolve-Path -LiteralPath $ModelPath).Path
} else {
    $Model = Get-ChildItem -LiteralPath $SnapshotRoot -Recurse -Filter $ModelPattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $Model) {
        throw "$ModelPattern was not found under $SnapshotRoot. Pass -ModelPath for another local GGUF."
    }

    $ResolvedModelPath = $Model.FullName
}

Write-Host "Starting Qwen3.6 35B-A3B MTP on http://127.0.0.1:$Port/v1"
Write-Host "Model: $ResolvedModelPath"
Write-Host "Context: $Context, DraftN: $DraftN, Reasoning: $Reasoning"

& $ServerPath `
    -m $ResolvedModelPath `
    --host 127.0.0.1 `
    --port $Port `
    -c $Context `
    --parallel 1 `
    --flash-attn on `
    --no-context-shift `
    -ngl 999 `
    --metrics `
    --jinja `
    --reasoning $Reasoning `
    --temp 0.6 `
    --top-p 0.95 `
    --top-k 20 `
    --min-p 0.00 `
    --cache-type-k f16 `
    --cache-type-v f16 `
    --spec-draft-type-k f16 `
    --spec-draft-type-v f16 `
    --spec-type draft-mtp `
    --spec-draft-n-max $DraftN `
    --spec-draft-ngl 999 `
    --batch-size 2048 `
    --ubatch-size 1536 `
    --threads 24 `
    --threads-batch 24 `
    --poll 100 `
    --poll-batch 1 `
    --no-mmap `
    --no-mmproj `
    --cache-ram 0 `
    --ctx-checkpoints 0 `
    --no-cache-prompt
