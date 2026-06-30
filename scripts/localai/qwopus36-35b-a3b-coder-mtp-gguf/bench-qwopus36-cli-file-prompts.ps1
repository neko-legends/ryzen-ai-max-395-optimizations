param(
    [string[]]$Case = @("hip-mtp-n2-t28-ub1024"),
    [string[]]$PromptFile = @(
        "C:\git\ryzen-ai-max-395-optimizations\benchmarks\prompts\book-context-10k.txt"
    ),
    [int]$Context = 262144,
    [int]$MaxTokens = 1024,
    [double]$Temperature = 0.0,
    [int]$Seed = 1234,
    [string]$ModelPath = "",
    [string]$ModelPattern = "Qwopus3.6-35B-A3B-Coder-MTP-Q5_K_M.gguf",
    [string[]]$SearchRoots = @(
        (Join-Path $HOME ".cache\huggingface\hub\models--Jackrong--Qwopus3.6-35B-A3B-Coder-MTP-GGUF\snapshots"),
        (Join-Path $HOME "Downloads")
    ),
    [string]$LlamaCliPath = (Join-Path $HOME ".unsloth\llama.cpp\build\bin\Release\llama-cli.exe"),
    [string]$OutCsv = "",
    [string]$LogDir = ""
)

$ErrorActionPreference = "Stop"
$Case = @($Case | ForEach-Object { $_ -split "," } | Where-Object { $_ })

function Resolve-QwopusModel {
    if ($ModelPath) {
        return (Resolve-Path -LiteralPath $ModelPath).Path
    }

    $candidates = @()
    foreach ($root in $SearchRoots) {
        if (Test-Path -LiteralPath $root) {
            $candidates += Get-ChildItem -LiteralPath $root -Recurse -Filter $ModelPattern -ErrorAction SilentlyContinue
        }
    }

    $model = $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $model) {
        throw "$ModelPattern was not found. Pass -ModelPath C:\path\to\$ModelPattern."
    }

    $model.FullName
}

function Get-CaseSpec {
    param([string]$Name)

    if ($Name -eq "hip-no-mtp-t28-ub1024") {
        return [pscustomobject]@{
            Name = $Name
            DraftN = 0
            Args = @("-b", "2048", "-ub", "1024", "-t", "28", "-tb", "28", "--poll", "100", "--poll-batch", "1", "--no-mmap")
        }
    }

    if ($Name -match "^hip-mtp-n([1-6])-t(16|24|28)-ub(512|1024|1536|2048)$") {
        return [pscustomobject]@{
            Name = $Name
            DraftN = [int]$Matches[1]
            Args = @(
                "-b", "2048", "-ub", $Matches[3], "-t", $Matches[2], "-tb", $Matches[2],
                "--poll", "100", "--poll-batch", "1", "--no-mmap",
                "--spec-type", "draft-mtp", "--spec-draft-n-max", $Matches[1],
                "--spec-draft-ngl", "999"
            )
        }
    }

    throw "Unknown case '$Name'. Try hip-mtp-n2-t28-ub1024, hip-mtp-n3-t28-ub1024, or hip-no-mtp-t28-ub1024."
}

function Get-TargetPromptTokens {
    param([string]$Path)

    $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    if ($name -match "10k") { return 10000 }
    if ($name -match "200k") { return 200000 }
    return 0
}

function Get-FileSha256 {
    param([string]$Path)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-KnownPromptTokens {
    param([string]$Sha256)

    switch ($Sha256) {
        "785c5b31d1ce77612431b1289c0a097ed51ab1a6d4a07bccfb7a70f59df55f94" { return 8907 }
        "a794ca243983eb3387bec6728db4b0c72a99ee2a98cfee7223269708e4ae228c" { return 174588 }
        default { return 0 }
    }
}

function Match-Last {
    param(
        [string]$Text,
        [string]$Pattern
    )

    $matches = [System.Text.RegularExpressions.Regex]::Matches($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($matches.Count -eq 0) {
        return $null
    }
    $matches[$matches.Count - 1]
}

function Invoke-QwopusCliBench {
    param(
        [pscustomobject]$Spec,
        [string]$PromptPath,
        [string]$Model
    )

    $resolvedPrompt = (Resolve-Path -LiteralPath $PromptPath).Path
    $promptText = Get-Content -LiteralPath $resolvedPrompt -Raw
    $promptSha = Get-FileSha256 -Path $resolvedPrompt
    $promptName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedPrompt)
    $stamp = "{0}-{1}-{2}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $promptName, $Spec.Name
    $consoleLog = Join-Path $LogDir "$stamp.console.log"
    $stderrLog = Join-Path $LogDir "$stamp.stderr.log"
    $llamaLog = Join-Path $LogDir "$stamp.llama.log"

    $args = @(
        "-m", $Model,
        "-f", $resolvedPrompt,
        "-n", "$MaxTokens",
        "-c", "$Context",
        "-ngl", "999",
        "-fa", "on",
        "--cache-type-k", "f16",
        "--cache-type-v", "f16",
        "--spec-draft-type-k", "f16",
        "--spec-draft-type-v", "f16",
        "--temp", "$Temperature",
        "-s", "$Seed",
        "-no-cnv",
        "-st",
        "--no-context-shift",
        "--no-display-prompt",
        "--log-file", $llamaLog
    ) + $Spec.Args

    Write-Host "Running $($Spec.Name) on $promptName..." -ForegroundColor Cyan
    $wall = [System.Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $LlamaCliPath -ArgumentList $args -RedirectStandardOutput $consoleLog -RedirectStandardError $stderrLog -PassThru -WindowStyle Hidden -Wait
    $exitCode = $process.ExitCode
    $wall.Stop()

    $text = ""
    if (Test-Path -LiteralPath $consoleLog) {
        $text += Get-Content -LiteralPath $consoleLog -Raw
    }
    if (Test-Path -LiteralPath $stderrLog) {
        $text += "`n" + (Get-Content -LiteralPath $stderrLog -Raw)
    }
    if (Test-Path -LiteralPath $llamaLog) {
        $text += "`n" + (Get-Content -LiteralPath $llamaLog -Raw)
    }

    $promptEval = Match-Last -Text $text -Pattern "prompt eval time\s*=\s*([0-9.]+) ms\s*/\s*([0-9]+) tokens.*?([0-9.]+) tokens per second"
    $eval = Match-Last -Text $text -Pattern "(?<!prompt )eval time\s*=\s*([0-9.]+) ms\s*/\s*([0-9]+) (?:runs|tokens).*?([0-9.]+) tokens per second"
    $compact = Match-Last -Text $text -Pattern "\[\s*Prompt:\s*([0-9.]+)\s*t/s\s*\|\s*Generation:\s*([0-9.]+)\s*t/s\s*\]"
    $total = Match-Last -Text $text -Pattern "total time\s*=\s*([0-9.]+) ms"
    $accept = Match-Last -Text $text -Pattern "draft acceptance = ([0-9.]+) \(\s*([0-9]+) accepted /\s*([0-9]+) generated"

    $knownPromptTokens = Get-KnownPromptTokens -Sha256 $promptSha
    $completionTokens = if ($eval) { [int]$eval.Groups[2].Value } elseif ($compact -and $exitCode -eq 0) { $MaxTokens } else { 0 }
    $wallTps = if ($wall.Elapsed.TotalSeconds -gt 0 -and $completionTokens -gt 0) {
        [math]::Round($completionTokens / $wall.Elapsed.TotalSeconds, 2)
    } else {
        0.0
    }

    [pscustomobject]@{
        timestamp_utc = (Get-Date).ToUniversalTime().ToString("s") + "Z"
        model = $Model
        case = $Spec.Name
        context = $Context
        max_tokens = $MaxTokens
        temperature = $Temperature
        seed = $Seed
        prompt_source = $resolvedPrompt
        prompt_style = $promptName
        target_prompt_tokens = Get-TargetPromptTokens -Path $resolvedPrompt
        prompt_chars = $promptText.Length
        prompt_sha256 = $promptSha
        prompt_tokens = if ($promptEval) { [int]$promptEval.Groups[2].Value } else { $knownPromptTokens }
        completion_tokens = $completionTokens
        prompt_tps = if ($promptEval) { [math]::Round([double]$promptEval.Groups[3].Value, 2) } elseif ($compact) { [math]::Round([double]$compact.Groups[1].Value, 2) } else { 0.0 }
        eval_tps = if ($eval) { [math]::Round([double]$eval.Groups[3].Value, 2) } elseif ($compact) { [math]::Round([double]$compact.Groups[2].Value, 2) } else { 0.0 }
        wall_seconds = [math]::Round($wall.Elapsed.TotalSeconds, 2)
        wall_tps = $wallTps
        total_ms = if ($total) { [math]::Round([double]$total.Groups[1].Value, 2) } else { 0.0 }
        draft_acceptance = if ($accept) { [math]::Round([double]$accept.Groups[1].Value, 4) } else { 0.0 }
        draft_accepted = if ($accept) { [int]$accept.Groups[2].Value } else { 0 }
        draft_generated = if ($accept) { [int]$accept.Groups[3].Value } else { 0 }
        exit_code = $exitCode
        console_log = $consoleLog
        stderr_log = $stderrLog
        llama_log = $llamaLog
        flags = ($args -join " ")
    }
}

if (-not (Test-Path -LiteralPath $LlamaCliPath)) {
    throw "llama-cli.exe not found at $LlamaCliPath. Build scripts/localai/tools/llama-cli-launcher.cpp into the Unsloth Release folder first."
}

$modelPath = Resolve-QwopusModel
$defaultResultDir = "C:\git\ryzen-ai-max-395-optimizations\results\qwopus36-35b-a3b-coder-mtp-gguf"
if (-not $LogDir) {
    $LogDir = Join-Path $defaultResultDir "logs"
}
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

if (-not $OutCsv) {
    $promptLabel = if ($PromptFile.Count -eq 1) {
        [System.IO.Path]::GetFileNameWithoutExtension($PromptFile[0])
    } else {
        "multi"
    }
    $OutCsv = Join-Path $defaultResultDir ("qwopus-q5-cli-ctx{0}-{1}-gen{2}-{3}.csv" -f ([int]($Context / 1024)), $promptLabel, $MaxTokens, (Get-Date -Format "yyyyMMdd-HHmmss"))
}

New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($OutCsv)) | Out-Null

$results = foreach ($prompt in $PromptFile) {
    foreach ($caseName in $Case) {
        Invoke-QwopusCliBench -Spec (Get-CaseSpec -Name $caseName) -PromptPath $prompt -Model $modelPath
    }
}

$results | Export-Csv -NoTypeInformation -Path $OutCsv
$results | Format-Table case, prompt_style, prompt_tokens, completion_tokens, prompt_tps, eval_tps, wall_tps, draft_acceptance, exit_code -AutoSize
Write-Host "Saved CSV: $OutCsv" -ForegroundColor Green
