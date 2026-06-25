param(
    [string[]]$Case = @("hip-mtp-n2"),
    [int]$Port = 8123,
    [int]$MaxTokens = 256,
    [int]$Context = 262144,
    [double]$Temperature = 0.0,
    [int]$Seed = 1234,
    [string]$ModelPath = "",
    [string]$ModelPattern = "Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf",
    [string[]]$SearchRoots = @(
        (Join-Path $HOME "Downloads"),
        (Join-Path $HOME ".cache\huggingface\hub\models--unsloth--Qwen3.6-35B-A3B-MTP-GGUF\snapshots")
    ),
    [string]$OutCsv = "",
    [switch]$KvUnified,
    [switch]$Mlock,
    [switch]$Metrics,
    [switch]$FitOff,
    [int]$CacheRam = 0,
    [string]$HipServerPath = (Join-Path $HOME ".unsloth\llama.cpp\build\bin\Release\llama-server.exe"),
    [string]$VulkanServerPath = (Join-Path $HOME ".cache\llama.cpp\b9704-vulkan\llama-server.exe")
)

$ErrorActionPreference = "Stop"
$Case = @($Case | ForEach-Object { $_ -split "," } | Where-Object { $_ })

$Prompt = @"
Write a compact but realistic PowerShell module that watches a project folder for new .log files, keeps only the newest five logs per subfolder, and prints a short JSON summary. Include helper functions, validation, and comments where useful. Return code only.
"@

function Resolve-QwenModel {
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
        throw "$ModelPattern was not found under: $roots. Pass -ModelPath C:\path\to\$ModelPattern if the GGUF is elsewhere."
    }

    $model.FullName
}

function Resolve-LlamaServer {
    param([ValidateSet("hip", "vulkan")] [string]$Backend)

    if ($Backend -eq "vulkan") {
        $server = $VulkanServerPath
    } else {
        $server = $HipServerPath
    }

    if (-not (Test-Path -LiteralPath $server)) {
        throw "$Backend llama-server.exe was not found at $server"
    }

    $server
}

function Get-CaseSpec {
    param([string]$Name)

    if ($Name -match "^hip-no-mtp-t(16|20|24|28)-ub(512|1024|1536|2048)$") {
        $threads = $Matches[1]
        $ubatch = $Matches[2]
        return [pscustomobject]@{
            Name = $Name
            Backend = "hip"
            Ctx = $Context
            Extra = @(
                "-b", "2048", "-ub", $ubatch, "-t", $threads, "-tb", $threads,
                "--poll", "100", "--poll-batch", "1", "--no-mmap"
            )
        }
    }

    if ($Name -match "^hip-mtp-n([1-6])$") {
        return [pscustomobject]@{
            Name = $Name
            Backend = "hip"
            Ctx = $Context
            Extra = @(
                "-b", "2048", "-ub", "1024", "-t", "16", "-tb", "16",
                "--poll", "100", "--poll-batch", "1", "--no-mmap",
                "--spec-type", "draft-mtp", "--spec-draft-n-max", $Matches[1],
                "--spec-draft-ngl", "999"
            )
        }
    }

    if ($Name -match "^hip-mtp-n2-t(8|12|16|20|24|28|32)$") {
        $threads = $Matches[1]
        return [pscustomobject]@{
            Name = $Name
            Backend = "hip"
            Ctx = $Context
            Extra = @(
                "-b", "2048", "-ub", "1024", "-t", $threads, "-tb", $threads,
                "--poll", "100", "--poll-batch", "1", "--no-mmap",
                "--spec-type", "draft-mtp", "--spec-draft-n-max", "2",
                "--spec-draft-ngl", "999"
            )
        }
    }

    if ($Name -match "^hip-mtp-n([1-6])-t(24|28)$") {
        $draftN = $Matches[1]
        $threads = $Matches[2]
        return [pscustomobject]@{
            Name = $Name
            Backend = "hip"
            Ctx = $Context
            Extra = @(
                "-b", "2048", "-ub", "1024", "-t", $threads, "-tb", $threads,
                "--poll", "100", "--poll-batch", "1", "--no-mmap",
                "--spec-type", "draft-mtp", "--spec-draft-n-max", $draftN,
                "--spec-draft-ngl", "999"
            )
        }
    }

    if ($Name -match "^hip-mtp-n([1-6])-t(24|28)-ub(512|1024|1536|2048)$") {
        $draftN = $Matches[1]
        $threads = $Matches[2]
        $ubatch = $Matches[3]
        return [pscustomobject]@{
            Name = $Name
            Backend = "hip"
            Ctx = $Context
            Extra = @(
                "-b", "2048", "-ub", $ubatch, "-t", $threads, "-tb", $threads,
                "--poll", "100", "--poll-batch", "1", "--no-mmap",
                "--spec-type", "draft-mtp", "--spec-draft-n-max", $draftN,
                "--spec-draft-ngl", "999"
            )
        }
    }

    if ($Name -match "^hip-mtp-n2-ub(512|1024|1536|2048)$") {
        $ubatch = $Matches[1]
        return [pscustomobject]@{
            Name = $Name
            Backend = "hip"
            Ctx = $Context
            Extra = @(
                "-b", "2048", "-ub", $ubatch, "-t", "16", "-tb", "16",
                "--poll", "100", "--poll-batch", "1", "--no-mmap",
                "--spec-type", "draft-mtp", "--spec-draft-n-max", "2",
                "--spec-draft-ngl", "999"
            )
        }
    }

    if ($Name -match "^hip-mtp-n2-b(1024|2048|4096)$") {
        $batch = $Matches[1]
        return [pscustomobject]@{
            Name = $Name
            Backend = "hip"
            Ctx = $Context
            Extra = @(
                "-b", $batch, "-ub", "1024", "-t", "16", "-tb", "16",
                "--poll", "100", "--poll-batch", "1", "--no-mmap",
                "--spec-type", "draft-mtp", "--spec-draft-n-max", "2",
                "--spec-draft-ngl", "999"
            )
        }
    }

    if ($Name -match "^hip-mtp-n2-poll(0|50|100)$") {
        $poll = $Matches[1]
        return [pscustomobject]@{
            Name = $Name
            Backend = "hip"
            Ctx = $Context
            Extra = @(
                "-b", "2048", "-ub", "1024", "-t", "16", "-tb", "16",
                "--poll", $poll, "--poll-batch", "1", "--no-mmap",
                "--spec-type", "draft-mtp", "--spec-draft-n-max", "2",
                "--spec-draft-ngl", "999"
            )
        }
    }

    switch ($Name) {
        "hip-studio-mtp-n2-262k" {
            [pscustomobject]@{
                Name = $Name
                Backend = "hip"
                Ctx = 262144
                Extra = @(
                    "-b", "2048", "-ub", "512", "-t", "2", "-tb", "2",
                    "--spec-type", "draft-mtp", "--spec-draft-n-max", "2"
                )
            }
            break
        }
        "hip-studio-mtp-n2" {
            [pscustomobject]@{
                Name = $Name
                Backend = "hip"
                Ctx = $Context
                Extra = @(
                    "-b", "2048", "-ub", "512", "-t", "2", "-tb", "2",
                    "--spec-type", "draft-mtp", "--spec-draft-n-max", "2"
                )
            }
            break
        }
        "hip-ngram-mtp-n2" {
            [pscustomobject]@{
                Name = $Name
                Backend = "hip"
                Ctx = $Context
                Extra = @(
                    "-b", "2048", "-ub", "1024", "-t", "16", "-tb", "16",
                    "--poll", "100", "--poll-batch", "1", "--no-mmap",
                    "--spec-type", "ngram-mod,draft-mtp", "--spec-draft-n-max", "2",
                    "--spec-draft-ngl", "999",
                    "--spec-ngram-mod-n-match", "24", "--spec-ngram-mod-n-min", "48", "--spec-ngram-mod-n-max", "64"
                )
            }
            break
        }
        "hip-ngram-mtp-n2-pmin075" {
            [pscustomobject]@{
                Name = $Name
                Backend = "hip"
                Ctx = $Context
                Extra = @(
                    "-b", "2048", "-ub", "1024", "-t", "16", "-tb", "16",
                    "--poll", "100", "--poll-batch", "1", "--no-mmap",
                    "--spec-type", "ngram-mod,draft-mtp", "--spec-draft-n-max", "2",
                    "--spec-draft-p-min", "0.75", "--spec-draft-ngl", "999",
                    "--spec-ngram-mod-n-match", "24", "--spec-ngram-mod-n-min", "48", "--spec-ngram-mod-n-max", "64"
                )
            }
            break
        }
        "hip-mtp-n2-q8kv" {
            [pscustomobject]@{
                Name = $Name
                Backend = "hip"
                Ctx = $Context
                Extra = @(
                    "-b", "2048", "-ub", "1024", "-t", "16", "-tb", "16",
                    "--poll", "100", "--poll-batch", "1", "--no-mmap",
                    "-ctk", "q8_0", "-ctv", "q8_0", "-ctkd", "q8_0", "-ctvd", "q8_0",
                    "--spec-type", "draft-mtp", "--spec-draft-n-max", "2",
                    "--spec-draft-ngl", "999"
                )
            }
            break
        }
        "hip-mtp-n2-q4kv" {
            [pscustomobject]@{
                Name = $Name
                Backend = "hip"
                Ctx = $Context
                Extra = @(
                    "-b", "2048", "-ub", "1024", "-t", "16", "-tb", "16",
                    "--poll", "100", "--poll-batch", "1", "--no-mmap",
                    "-ctk", "q4_0", "-ctv", "q4_0", "-ctkd", "q4_0", "-ctvd", "q4_0",
                    "--spec-type", "draft-mtp", "--spec-draft-n-max", "2",
                    "--spec-draft-ngl", "999"
                )
            }
            break
        }
        "hip-mtp-n2-mmap" {
            [pscustomobject]@{
                Name = $Name
                Backend = "hip"
                Ctx = $Context
                Extra = @(
                    "-b", "2048", "-ub", "1024", "-t", "16", "-tb", "16",
                    "--poll", "100", "--poll-batch", "1",
                    "--spec-type", "draft-mtp", "--spec-draft-n-max", "2",
                    "--spec-draft-ngl", "999"
                )
            }
            break
        }
        "hip-mtp-n2-pmin075" {
            [pscustomobject]@{
                Name = $Name
                Backend = "hip"
                Ctx = $Context
                Extra = @(
                    "-b", "2048", "-ub", "1024", "-t", "16", "-tb", "16",
                    "--poll", "100", "--poll-batch", "1", "--no-mmap",
                    "--spec-type", "draft-mtp", "--spec-draft-n-max", "2",
                    "--spec-draft-p-min", "0.75", "--spec-draft-ngl", "999"
                )
            }
            break
        }
        "vulkan-mtp-n2" {
            [pscustomobject]@{
                Name = $Name
                Backend = "vulkan"
                Ctx = $Context
                Extra = @(
                    "-b", "2048", "-ub", "1024", "-t", "16", "-tb", "16",
                    "--poll", "100", "--poll-batch", "1", "--no-mmap",
                    "--spec-type", "draft-mtp", "--spec-draft-n-max", "2",
                    "--spec-draft-ngl", "999"
                )
            }
            break
        }
        default {
            throw "Unknown benchmark case '$Name'"
        }
    }
}

function Invoke-QwenBenchCase {
    param(
        [pscustomobject]$Spec,
        [string]$Model
    )

    $server = Resolve-LlamaServer -Backend $Spec.Backend
    $stamp = "{0}-{1}" -f $Spec.Name, ([guid]::NewGuid().ToString("N").Substring(0, 8))
    $stdout = Join-Path $env:TEMP "$stamp.out.log"
    $stderr = Join-Path $env:TEMP "$stamp.err.log"
    Remove-Item $stdout, $stderr -ErrorAction SilentlyContinue

    $args = @(
        "-m", $Model,
        "--host", "127.0.0.1",
        "--port", "$Port",
        "-ngl", "999",
        "-c", "$($Spec.Ctx)",
        "-np", "1",
        "--jinja",
        "--reasoning", "off",
        "--no-mmproj",
        "-fa", "on",
        "--cache-type-k", "f16",
        "--cache-type-v", "f16",
        "--spec-draft-type-k", "f16",
        "--spec-draft-type-v", "f16",
        "--no-cache-prompt",
        "--cache-ram", "$CacheRam",
        "--ctx-checkpoints", "0"
    ) + $Spec.Extra

    if ($KvUnified) {
        $args += "--kv-unified"
    }
    if ($Mlock) {
        $args += "--mlock"
    }
    if ($Metrics) {
        $args += "--metrics"
    }
    if ($FitOff) {
        $args += @("--fit", "off")
    }

    Write-Host "Running $($Spec.Name) on $($Spec.Backend)..." -ForegroundColor Cyan
    $process = Start-Process -FilePath $server -ArgumentList $args -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden

    try {
        $ready = $false
        for ($i = 0; $i -lt 240; $i++) {
            Start-Sleep -Seconds 1
            if ($process.HasExited) {
                throw "llama-server exited early for $($Spec.Name)"
            }
            try {
                Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 | Out-Null
                $ready = $true
                break
            } catch {
            }
        }
        if (-not $ready) {
            throw "llama-server did not become ready for $($Spec.Name)"
        }

        $body = @{
            model = "local"
            messages = @(@{ role = "user"; content = $Prompt })
            max_tokens = $MaxTokens
            temperature = $Temperature
            seed = $Seed
            stream = $false
        } | ConvertTo-Json -Depth 8

        $wall = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/v1/chat/completions" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 600
        $wall.Stop()

        Start-Sleep -Milliseconds 500
        $log = Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue
        $eval = $log | Select-String -Pattern "\|\s+eval time\s+=\s+([0-9.]+) ms /\s+([0-9]+) tokens.*?([0-9.]+) tokens per second" | Select-Object -Last 1
        $promptEval = $log | Select-String -Pattern "prompt eval time\s+=\s+([0-9.]+) ms /\s+([0-9]+) tokens.*?([0-9.]+) tokens per second" | Select-Object -Last 1
        $accept = $log | Select-String -Pattern "draft acceptance = ([0-9.]+) \(\s*([0-9]+) accepted /\s*([0-9]+) generated" | Select-Object -Last 1
        $ngram = $log | Select-String -Pattern "statistics\s+ngram_mod:.*#acc tokens =\s*([0-9]+)" | Select-Object -Last 1

        $evalTps = if ($eval) { [double]$eval.Matches[0].Groups[3].Value } else { 0.0 }
        $promptTps = if ($promptEval) { [double]$promptEval.Matches[0].Groups[3].Value } else { 0.0 }
        $acceptRate = if ($accept) { [double]$accept.Matches[0].Groups[1].Value } else { 0.0 }
        $accepted = if ($accept) { [int]$accept.Matches[0].Groups[2].Value } else { 0 }
        $generated = if ($accept) { [int]$accept.Matches[0].Groups[3].Value } else { 0 }
        $ngramAccepted = if ($ngram) { [int]$ngram.Matches[0].Groups[1].Value } else { 0 }

        [pscustomobject]@{
            case = $Spec.Name
            backend = $Spec.Backend
            context = $Spec.Ctx
            kv_unified = [bool]$KvUnified
            mlock = [bool]$Mlock
            metrics = [bool]$Metrics
            fit_off = [bool]$FitOff
            cache_ram = $CacheRam
            completion_tokens = $response.usage.completion_tokens
            eval_tps = [math]::Round($evalTps, 2)
            prompt_tps = [math]::Round($promptTps, 2)
            wall_tps = [math]::Round($response.usage.completion_tokens / $wall.Elapsed.TotalSeconds, 2)
            draft_acceptance = [math]::Round($acceptRate, 4)
            draft_accepted = $accepted
            draft_generated = $generated
            ngram_accepted = $ngramAccepted
            log = $stderr
        }
    } finally {
        if ($process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $process.WaitForExit(5000) | Out-Null
        }
    }
}

$modelPath = if ($ModelPath) { (Resolve-Path -LiteralPath $ModelPath).Path } else { Resolve-QwenModel }
$results = foreach ($caseName in $Case) {
    Invoke-QwenBenchCase -Spec (Get-CaseSpec -Name $caseName) -Model $modelPath
}

$results | Format-Table -AutoSize

if ($OutCsv) {
    $results | Export-Csv -LiteralPath $OutCsv -NoTypeInformation
    Write-Host "Wrote $OutCsv"
}
