param(
    [string]$RepoId = "Jackrong/Qwopus3.6-35B-A3B-Coder-MTP-GGUF",
    [string]$FileName = "Qwopus3.6-35B-A3B-Coder-MTP-Q5_K_M.gguf",
    [string]$LocalDir = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Get-ManualSnapshotDir {
    Join-Path $HOME ".cache\huggingface\hub\models--Jackrong--Qwopus3.6-35B-A3B-Coder-MTP-GGUF\snapshots\manual"
}

function Invoke-HfDownloadCommand {
    param([string]$CommandName)

    $hfArgs = @("download", $RepoId, $FileName)
    if ($LocalDir) {
        New-Item -ItemType Directory -Force -Path $LocalDir | Out-Null
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

function Invoke-CurlDownload {
    param(
        [string]$CurlPath,
        [string]$Destination
    )

    $url = "https://huggingface.co/$RepoId/resolve/main/$FileName"
    $destinationDir = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null

    $partial = "$Destination.part"
    $curlArgs = @(
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

function Find-DownloadedModel {
    $roots = if ($LocalDir) {
        @($LocalDir)
    } else {
        @(Join-Path $HOME ".cache\huggingface\hub\models--Jackrong--Qwopus3.6-35B-A3B-Coder-MTP-GGUF\snapshots")
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

$targetDir = if ($LocalDir) { $LocalDir } else { Get-ManualSnapshotDir }
$destination = Join-Path $targetDir $FileName

if ($Force) {
    Remove-Item -LiteralPath $destination, "$destination.part" -Force -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $destination) {
    Write-Host "Already downloaded: $destination"
} else {
    $hf = Get-Command hf -ErrorAction SilentlyContinue
    $huggingfaceCli = Get-Command huggingface-cli -ErrorAction SilentlyContinue

    if ($hf) {
        Invoke-HfDownloadCommand -CommandName $hf.Source
    } elseif ($huggingfaceCli) {
        Invoke-HfDownloadCommand -CommandName $huggingfaceCli.Source
    } else {
        $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
        if (-not $curl) {
            throw "Neither hf, huggingface-cli, nor curl.exe was found."
        }
        Invoke-CurlDownload -CurlPath $curl.Source -Destination $destination
    }
}

$modelPath = Find-DownloadedModel
Write-Host ""
Write-Host "Download complete."
if ($modelPath) {
    Write-Host "Model: $modelPath"
} else {
    Write-Host "Model should be under: $targetDir"
}
