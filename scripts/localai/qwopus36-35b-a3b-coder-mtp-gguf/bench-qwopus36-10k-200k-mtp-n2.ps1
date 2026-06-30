param(
    [int]$MaxTokens = 1024,
    [string]$OutCsv = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bench = Join-Path $scriptDir "bench-qwopus36-cli-file-prompts.ps1"

if (-not $OutCsv) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutCsv = "C:\git\ryzen-ai-max-395-optimizations\results\qwopus36-35b-a3b-coder-mtp-gguf\qwopus-q5-cli-ctx262k-book-10k-200k-gen$MaxTokens-mtp-n2-$stamp.csv"
}

& $bench `
    -Case "hip-mtp-n2-t28-ub1024" `
    -PromptFile @(
        "C:\git\ryzen-ai-max-395-optimizations\benchmarks\prompts\book-context-10k.txt",
        "C:\git\ryzen-ai-max-395-optimizations\benchmarks\prompts\book-context-200k.txt"
    ) `
    -MaxTokens $MaxTokens `
    -OutCsv $OutCsv
