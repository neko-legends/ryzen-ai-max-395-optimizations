param(
    [string]$RepoId = "deepreinforce-ai/Ornith-1.0-35B-GGUF",
    [string]$FileName = "ornith-1.0-35b-Q5_K_M.gguf",
    [string]$LocalDir = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Net.Http

function Invoke-HfDownloadCommand {
    param([string]$CommandName)

    $hfArgs = @("download", $RepoId, $FileName)
    if ($LocalDir) {
        if (-not (Test-Path -LiteralPath $LocalDir)) {
            New-Item -ItemType Directory -Force -Path $LocalDir | Out-Null
        }
        $hfArgs += @("--local-dir", $LocalDir)
    }
    if ($Force) {
        $hfArgs += "--force-download"
    }

    Write-Host "Using $CommandName to download $RepoId/$FileName"
    & $CommandName @hfArgs
    if ($LASTEXITCODE -ne 0) {
        throw "$CommandName failed with exit code $LASTEXITCODE"
    }
}

function Get-ManualSnapshotDir {
    Join-Path $HOME ".cache\huggingface\hub\models--deepreinforce-ai--Ornith-1.0-35B-GGUF\snapshots\manual"
}

function Invoke-CurlDownload {
    param(
        [string]$CurlPath,
        [string]$Destination
    )

    $url = "https://huggingface.co/$RepoId/resolve/main/$FileName"
    $destinationDir = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    }

    $partial = "$Destination.part"
    $curlArgs = @(
        "--silent",
        "--show-error",
        "--no-progress-meter",
        "--location",
        "--fail",
        "--retry", "20",
        "--retry-delay", "5",
        "--speed-time", "60",
        "--speed-limit", "1024",
        "--continue-at", "-",
        "--output", $partial,
        $url
    )

    if ($env:HF_TOKEN) {
        $curlArgs = @("--header", "Authorization: Bearer $env:HF_TOKEN") + $curlArgs
    }

    Write-Host "Using curl.exe for resumable download."
    Write-Host "Source: $url"
    Write-Host "Target: $Destination"
    & $CurlPath @curlArgs
    if ($LASTEXITCODE -ne 0) {
        throw "curl.exe failed with exit code $LASTEXITCODE"
    }

    Move-Item -LiteralPath $partial -Destination $Destination -Force
}

function Invoke-DirectDownload {
    param([string]$Destination)

    $url = "https://huggingface.co/$RepoId/resolve/main/$FileName"
    $destinationDir = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    }

    $partial = "$Destination.part"
    $existing = if (Test-Path -LiteralPath $partial) { (Get-Item -LiteralPath $partial).Length } else { 0 }

    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromHours(24)
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $url)

    if ($existing -gt 0) {
        $request.Headers.Range = [System.Net.Http.Headers.RangeHeaderValue]::new($existing, $null)
    }

    if ($env:HF_TOKEN) {
        $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $env:HF_TOKEN)
    }

    Write-Host "Using direct HTTPS download."
    Write-Host "Source: $url"
    Write-Host "Target: $Destination"
    if ($existing -gt 0) {
        Write-Host "Resuming from $([math]::Round($existing / 1GB, 2)) GiB"
    }

    $response = $null
    $inputStream = $null
    $outputStream = $null
    try {
        $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()

        if ($existing -gt 0 -and $response.StatusCode -eq [System.Net.HttpStatusCode]::OK) {
            $existing = 0
            [System.IO.File]::WriteAllBytes($partial, [byte[]]::new(0))
        }

        $response.EnsureSuccessStatusCode()

        $remaining = $response.Content.Headers.ContentLength
        $total = if ($remaining) { $existing + [int64]$remaining } else { 0 }
        $inputStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $mode = if ($existing -gt 0) { [System.IO.FileMode]::Append } else { [System.IO.FileMode]::Create }
        $outputStream = [System.IO.File]::Open($partial, $mode, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $buffer = [byte[]]::new(8MB)
        $done = [int64]$existing
        $started = Get-Date
        $lastReport = Get-Date "2000-01-01"

        while ($true) {
            $read = $inputStream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) {
                break
            }

            $outputStream.Write($buffer, 0, $read)
            $done += $read

            $now = Get-Date
            if (($now - $lastReport).TotalSeconds -ge 10) {
                $elapsed = [math]::Max(0.001, ($now - $started).TotalSeconds)
                $speed = (($done - $existing) / 1MB) / $elapsed
                if ($total -gt 0) {
                    $pct = $done * 100.0 / $total
                    Write-Host ("{0:N2} GiB / {1:N2} GiB ({2:N1}%), {3:N1} MiB/s" -f ($done / 1GB), ($total / 1GB), $pct, $speed)
                } else {
                    Write-Host ("{0:N2} GiB downloaded, {1:N1} MiB/s" -f ($done / 1GB), $speed)
                }
                $lastReport = $now
            }
        }
    } finally {
        if ($outputStream) { $outputStream.Dispose() }
        if ($inputStream) { $inputStream.Dispose() }
        if ($response) { $response.Dispose() }
        $client.Dispose()
    }

    Move-Item -LiteralPath $partial -Destination $Destination -Force
}

function Find-DownloadedModel {
    $roots = if ($LocalDir) {
        @($LocalDir)
    } else {
        @(Join-Path $HOME ".cache\huggingface\hub\models--deepreinforce-ai--Ornith-1.0-35B-GGUF\snapshots")
    }

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        $model = Get-ChildItem -LiteralPath $root -Recurse -Filter $FileName -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($model) {
            return $model.FullName
        }
    }

    return ""
}

$hf = Get-Command hf -ErrorAction SilentlyContinue
$huggingfaceCli = Get-Command huggingface-cli -ErrorAction SilentlyContinue

if ($hf) {
    Invoke-HfDownloadCommand -CommandName $hf.Source
} elseif ($huggingfaceCli) {
    Invoke-HfDownloadCommand -CommandName $huggingfaceCli.Source
} else {
    $targetDir = if ($LocalDir) { $LocalDir } else { Get-ManualSnapshotDir }
    $destination = Join-Path $targetDir $FileName
    if ($Force) {
        Remove-Item -LiteralPath $destination, "$destination.part" -Force -ErrorAction SilentlyContinue
    }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        Invoke-CurlDownload -CurlPath $curl.Source -Destination $destination
    } else {
        Invoke-DirectDownload -Destination $destination
    }
}

$modelPath = Find-DownloadedModel
Write-Host ""
Write-Host "Download complete."
if ($modelPath) {
    Write-Host "Model: $modelPath"
} elseif ($LocalDir) {
    Write-Host "Model should be under: $LocalDir"
} else {
    Write-Host "Model should be in the default Hugging Face cache."
}
