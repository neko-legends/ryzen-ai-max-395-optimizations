param(
    [string[]]$Case = @("hip-no-mtp-t28-ub1024"),
    [int]$Port = 8124,
    [int]$MaxTokens = 256,
    [int]$Runs = 1,
    [int]$Context = 262144,
    [double]$Temperature = 0.0,
    [int]$Seed = 1234,
    [string]$ModelPath = "",
    [string]$ModelPattern = "ornith-1.0-35b-Q5_K_M.gguf",
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
    [string]$ModelId = "ornith-1.0-35b-q5-k-m",
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
Add-Type -AssemblyName System.Web
$Case = @($Case | ForEach-Object { $_ -split "," } | Where-Object { $_ })

function Get-RepoRoot {
    (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
}

function Resolve-RepoPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return (Resolve-Path -LiteralPath $Path).Path
    }

    return (Resolve-Path -LiteralPath (Join-Path (Get-RepoRoot) $Path)).Path
}

function Get-TextSha256 {
    param([string]$Text)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Resolve-BenchmarkPrompt {
    if ($Prompt -and $PromptFile) {
        throw "Pass either -Prompt or -PromptFile, not both."
    }

    if ($PromptFile) {
        $resolvedPromptFile = Resolve-RepoPath -Path $PromptFile
        $promptText = Get-Content -LiteralPath $resolvedPromptFile -Raw -Encoding UTF8
        return [pscustomobject]@{
            Text = $promptText
            Source = $resolvedPromptFile
            Chars = $promptText.Length
            Sha256 = (Get-FileHash -LiteralPath $resolvedPromptFile -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }

    if ($Prompt) {
        return [pscustomobject]@{
            Text = $Prompt
            Source = "inline"
            Chars = $Prompt.Length
            Sha256 = Get-TextSha256 -Text $Prompt
        }
    }

    $defaultPrompt = @"
Write a compact but realistic PowerShell module that watches a project folder for new .log files, keeps only the newest five logs per subfolder, and prints a short JSON summary. Include helper functions, validation, and comments where useful. Return code only.
"@

    return [pscustomobject]@{
        Text = $defaultPrompt
        Source = "default"
        Chars = $defaultPrompt.Length
        Sha256 = Get-TextSha256 -Text $defaultPrompt
    }
}

function Invoke-JsonPost {
    param(
        [string]$Uri,
        [string]$Body,
        [int]$TimeoutSeconds
    )

    $request = [System.Net.WebRequest]::Create($Uri)
    $request.Method = "POST"
    $request.ContentType = "application/json"
    $request.Accept = "application/json"
    $request.Timeout = $TimeoutSeconds * 1000
    $request.ReadWriteTimeout = $TimeoutSeconds * 1000

    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $request.ContentLength = $bodyBytes.Length

    $requestStream = $request.GetRequestStream()
    try {
        $requestStream.Write($bodyBytes, 0, $bodyBytes.Length)
    } finally {
        $requestStream.Dispose()
    }

    try {
        $response = $request.GetResponse()
    } catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            try {
                $errorBody = $reader.ReadToEnd()
            } finally {
                $reader.Dispose()
            }
            throw "HTTP $([int]$_.Exception.Response.StatusCode) $($_.Exception.Response.StatusDescription): $errorBody"
        }
        throw
    }

    try {
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        try {
            return $reader.ReadToEnd() | ConvertFrom-Json
        } finally {
            $reader.Dispose()
        }
    } finally {
        $response.Dispose()
    }
}

function New-ChatCompletionJson {
    param(
        [string]$Model,
        [string]$Content
    )

    $escapedModel = [System.Web.HttpUtility]::JavaScriptStringEncode($Model)
    $escapedContent = [System.Web.HttpUtility]::JavaScriptStringEncode($Content)
    $temperatureText = $Temperature.ToString([System.Globalization.CultureInfo]::InvariantCulture)

    return ('{{"model":"{0}","messages":[{{"role":"user","content":"{1}"}}],"max_tokens":{2},"temperature":{3},"seed":{4},"stream":false}}' -f `
        $escapedModel,
        $escapedContent,
        $MaxTokens,
        $temperatureText,
        $Seed)
}

function Resolve-OrnithModel {
    if ($ModelPath) {
        return (Resolve-Path -LiteralPath $ModelPath).Path
    }

    $candidates = @()
    foreach ($root in $SearchRoots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        $candidates += Get-ChildItem -LiteralPath $root -Recurse -Filter $ModelPattern -ErrorAction SilentlyContinue
    }

    $model = $candidates |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $model) {
        $roots = $SearchRoots -join ", "
        throw "$ModelPattern was not found under: $roots. Run download-ornith-1.0-35b-q5-k-m.bat or pass -ModelPath C:\path\to\$ModelPattern."
    }

    $model.FullName
}

function Get-CaseSpec {
    param([string]$Name)

    if ($Name -match "^hip-no-mtp-t(16|20|24|28|32)-ub(512|1024|1536|2048)$") {
        $threads = $Matches[1]
        $ubatch = $Matches[2]
        return [pscustomobject]@{
            Name = $Name
            Ctx = $Context
            Extra = @(
                "-b", "2048", "-ub", $ubatch, "-t", $threads, "-tb", $threads,
                "--poll", "100", "--poll-batch", "1", "--no-mmap"
            )
        }
    }

    if ($Name -eq "hip-no-mtp-default") {
        return [pscustomobject]@{
            Name = "hip-no-mtp-t28-ub1024"
            Ctx = $Context
            Extra = @(
                "-b", "2048", "-ub", "1024", "-t", "28", "-tb", "28",
                "--poll", "100", "--poll-batch", "1", "--no-mmap"
            )
        }
    }

    throw "Unknown benchmark case '$Name'. Try hip-no-mtp-t28-ub1024 or hip-no-mtp-t24-ub1536."
}

function Invoke-OrnithBenchCase {
    param(
        [pscustomobject]$Spec,
        [string]$Model,
        [pscustomobject]$PromptSpec
    )

    if (-not (Test-Path -LiteralPath $ServerPath)) {
        throw "llama-server.exe was not found at $ServerPath"
    }

    $stamp = "{0}-{1}" -f $Spec.Name, ([guid]::NewGuid().ToString("N").Substring(0, 8))
    $stdout = Join-Path $env:TEMP "$stamp.out.log"
    $stderr = Join-Path $env:TEMP "$stamp.err.log"
    Remove-Item $stdout, $stderr -ErrorAction SilentlyContinue

    $llamaArgs = @(
        "-m", $Model,
        "--alias", $ModelId,
        "--host", "127.0.0.1",
        "--port", "$Port",
        "-ngl", "999",
        "-c", "$($Spec.Ctx)",
        "-np", "1",
        "--flash-attn", "on",
        "--no-context-shift",
        "--metrics",
        "--jinja",
        "--reasoning", $Reasoning,
        "--cache-type-k", $CacheTypeK,
        "--cache-type-v", $CacheTypeV,
        "--no-mmproj",
        "--no-cache-prompt",
        "--cache-ram", "$CacheRam",
        "--ctx-checkpoints", "0"
    ) + $Spec.Extra

    if ($Reasoning -ne "off" -and $ReasoningBudget -ge 0) {
        $llamaArgs += @("--reasoning-budget", "$ReasoningBudget")
    }

    if ($Mlock) {
        $llamaArgs += "--mlock"
    }

    Write-Host "Running $($Spec.Name)..." -ForegroundColor Cyan
    $process = Start-Process -FilePath $ServerPath -ArgumentList $llamaArgs -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden

    try {
        $ready = $false
        for ($i = 0; $i -lt $StartupTimeoutSeconds; $i++) {
            Start-Sleep -Seconds 1
            if ($process.HasExited) {
                throw "llama-server exited early for $($Spec.Name). Check $stderr"
            }
            try {
                Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 | Out-Null
                $ready = $true
                break
            } catch {
            }
        }
        if (-not $ready) {
            throw "llama-server did not become ready for $($Spec.Name). Check $stderr"
        }

        $rows = @()
        for ($run = 1; $run -le $Runs; $run++) {
            $body = New-ChatCompletionJson -Model $ModelId -Content $PromptSpec.Text

            $wall = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-JsonPost -Uri "http://127.0.0.1:$Port/v1/chat/completions" -Body $body -TimeoutSeconds $RequestTimeoutSeconds
            $wall.Stop()

            Start-Sleep -Milliseconds 500
            $log = Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue
            $eval = $log | Select-String -Pattern "\|\s+eval time\s+=\s+([0-9.]+) ms /\s+([0-9]+) tokens.*?([0-9.]+) tokens per second" | Select-Object -Last 1
            $promptEval = $log | Select-String -Pattern "prompt eval time\s+=\s+([0-9.]+) ms /\s+([0-9]+) tokens.*?([0-9.]+) tokens per second" | Select-Object -Last 1

            $evalTps = if ($eval) { [double]$eval.Matches[0].Groups[3].Value } else { 0.0 }
            $promptTps = if ($promptEval) { [double]$promptEval.Matches[0].Groups[3].Value } else { 0.0 }
            $completionTokens = if ($response.usage) { [int]$response.usage.completion_tokens } else { 0 }
            $promptTokens = if ($response.usage) { [int]$response.usage.prompt_tokens } else { 0 }
            $totalTokens = if ($response.usage) { [int]$response.usage.total_tokens } else { 0 }

            $rows += [pscustomobject]@{
                case = $Spec.Name
                run = $run
                model = $ModelId
                model_file = Split-Path -Leaf $Model
                context = $Spec.Ctx
                reasoning = $Reasoning
                cache_type_k = $CacheTypeK
                cache_type_v = $CacheTypeV
                cache_ram = $CacheRam
                max_tokens = $MaxTokens
                prompt_style = $PromptStyle
                target_prompt_tokens = $TargetPromptTokens
                prompt_source = $PromptSpec.Source
                prompt_chars = $PromptSpec.Chars
                prompt_sha256 = $PromptSpec.Sha256
                prompt_tokens = $promptTokens
                completion_tokens = $completionTokens
                total_tokens = $totalTokens
                eval_tps = [math]::Round($evalTps, 2)
                prompt_tps = [math]::Round($promptTps, 2)
                wall_seconds = [math]::Round($wall.Elapsed.TotalSeconds, 3)
                wall_tps = if ($wall.Elapsed.TotalSeconds -gt 0) { [math]::Round($completionTokens / $wall.Elapsed.TotalSeconds, 2) } else { 0 }
                log = $stderr
            }
        }

        return $rows
    } finally {
        if ($process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $process.WaitForExit(5000) | Out-Null
        }
    }
}

$resolvedModelPath = Resolve-OrnithModel
$resolvedPrompt = Resolve-BenchmarkPrompt
Write-Host ("Prompt source: {0}" -f $resolvedPrompt.Source)
Write-Host ("Prompt chars: {0:n0}, sha256: {1}" -f $resolvedPrompt.Chars, $resolvedPrompt.Sha256)

$results = foreach ($caseName in $Case) {
    Invoke-OrnithBenchCase -Spec (Get-CaseSpec -Name $caseName) -Model $resolvedModelPath -PromptSpec $resolvedPrompt
}

$results | Format-Table -AutoSize

if (-not $OutCsv) {
    $repoRoot = Get-RepoRoot
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutCsv = Join-Path $repoRoot "results\ornith-1.0-35b-gguf\ornith-1.0-35b-q5-k-m-$stamp.csv"
}

$outDir = Split-Path -Parent $OutCsv
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$results | Export-Csv -LiteralPath $OutCsv -NoTypeInformation
Write-Host "Wrote $OutCsv"
