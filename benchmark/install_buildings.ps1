$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$target = Join-Path $root "Buildings 14.0.0"

if (Test-Path $target) {
    $package = Join-Path $target "package.mo"

    if (-not (Test-Path $package)) {
        throw "Buildings directory exists but package.mo is missing."
    }

    if (-not (Select-String -Path $package -Pattern 'version="14\.0\.0"' -Quiet)) {
        throw "Existing Buildings library is not version 14.0.0."
    }

    Write-Host "Buildings 14.0.0 already installed."
    exit 0
}

$url = "https://github.com/lbl-srg/modelica-buildings/releases/download/v14.0.0/Buildings-v14.0.0.zip"

$temp = Join-Path ([System.IO.Path]::GetTempPath()) (
    "datacenter-peakshaving-benchmark-buildings-" + [guid]::NewGuid().ToString("N")
)

New-Item -ItemType Directory -Path $temp | Out-Null

try {
    $zip = Join-Path $temp "Buildings.zip"
    $extract = Join-Path $temp "extracted"

    Write-Host "Downloading official Buildings 14.0.0..."

    Invoke-WebRequest -Uri $url -OutFile $zip

    Write-Host "Extracting Buildings library..."

    New-Item -ItemType Directory -Path $extract | Out-Null

& tar.exe -xf $zip -C $extract

if ($LASTEXITCODE -ne 0) {
    throw "tar.exe extraction failed."
}

    $package = Get-ChildItem $extract -Recurse -File -Filter "package.mo" |
        Where-Object {
            $_.Directory.Name -in @("Buildings", "Buildings 14.0.0")
        } |
        Where-Object {
            Select-String -Path $_.FullName `
                -Pattern 'version="14\.0\.0"' -Quiet
        } |
        Select-Object -First 1

    if (-not $package) {
        throw "Cannot locate Buildings 14.0.0 package.mo in archive."
    }

    Move-Item -Path $package.Directory.FullName -Destination $target

    Write-Host "Buildings 14.0.0 installed successfully."
}
finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}



