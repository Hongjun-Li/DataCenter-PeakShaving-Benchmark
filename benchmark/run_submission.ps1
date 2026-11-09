$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$resultFile = Join-Path $projectRoot "RenewablesStarter48h_res.mat"
$scoreLog = Join-Path $projectRoot "benchmark\evaluation\submission_score.log"

Write-Host "=== DataCenter-PeakShaving-Benchmark Submission Runner ==="


# Ensure the required Buildings library is available.
Write-Host "Checking Buildings 14.0.0 dependency..."

$buildingsInstaller = Join-Path $PSScriptRoot "install_buildings.ps1"

if (-not (Test-Path $buildingsInstaller)) {
    throw "Buildings installer is missing."
}

& $buildingsInstaller

Write-Host "Buildings 14.0.0 dependency ready."

Write-Host "Checking Modelica 4.1.0 environment..."

$setupOutput = & docker run --rm `
    -v "${projectRoot}:/work" `
    -v openmodelica-libraries:/root/.openmodelica `
    -w /work `
    openmodelica/openmodelica:v1.27.1-minimal `
    omc benchmark/setup_environment.mos 2>&1

$setupExitCode = $LASTEXITCODE
$setupText = $setupOutput | Out-String

if ($setupExitCode -ne 0 -or
    -not $setupText.Contains("Modelica 4.1.0 installation result: true") -or
    -not $setupText.Contains("Modelica 4.1.0 load result: true")) {

    Write-Host $setupText
    throw "Modelica environment setup failed."
}

Write-Host "Modelica 4.1.0 environment ready."


if (Test-Path $resultFile) {
    Remove-Item $resultFile -Force
    Write-Host "Removed previous simulation result."
}

Write-Host "Running 48-hour Starter simulation..."

$simulationOutput = & docker run --rm `
    -v "${projectRoot}:/work" `
    -v openmodelica-libraries:/root/.openmodelica `
    -w /work `
    openmodelica/openmodelica:v1.27.1-minimal `
    omc scripts/peak_shaving/simulate_starter_48h.mos 2>&1

$simulationText = $simulationOutput | Out-String
$simulationText | Write-Host

if ($LASTEXITCODE -ne 0 -or
    -not (Test-Path $resultFile) -or
    -not $simulationText.Contains("The simulation finished successfully.")) {
    throw "Starter simulation failed. Scoring aborted."
}

# Validate required simulation result files.

$idleFile = Join-Path $projectRoot "RenewablesBatteryIdleWind48h_res.mat"


if (-not (Test-Path $idleFile)) {
    Write-Host "Baseline result missing. Generating baseline..."

    $baselineOutput = & docker run --rm `
        -v "${projectRoot}:/work" `
        -v openmodelica-libraries:/root/.openmodelica `
        -w /work `
        openmodelica/openmodelica:v1.27.1-minimal `
        omc benchmark/evaluation/generate_baseline.mos 2>&1

    $baselineExitCode = $LASTEXITCODE
    $baselineText = $baselineOutput | Out-String
    $baselineText | Write-Host

    if ($baselineExitCode -ne 0 -or
        -not (Test-Path $idleFile) -or
        -not $baselineText.Contains("The simulation finished successfully.")) {

        throw "Battery-Idle baseline generation failed."
    }

    Write-Host "Battery-Idle baseline generated successfully."
}


if (-not (Test-Path $resultFile)) {
    throw "Starter simulation result is missing: $resultFile"
}

$idleInfo = Get-Item $idleFile
$resultInfo = Get-Item $resultFile

if ($idleInfo.Length -le 0) {
    throw "Battery-Idle baseline result is empty."
}

if ($resultInfo.Length -le 0) {
    throw "Starter simulation result is empty."
}

Write-Host "Result files exist and are non-empty."

Write-Host "Running benchmark scoring..."

$scoreOutput = & docker run --rm `
    -v "${projectRoot}:/work" `
    -w /work `
    openmodelica/openmodelica:v1.27.1-minimal `
    omc benchmark/evaluation/score_submission.mos 2>&1

$scoreText = $scoreOutput | Out-String
$scoreText | Set-Content $scoreLog

if ($LASTEXITCODE -ne 0 -or
    -not $scoreText.Contains("Final benchmark score [%]:")) {
    throw "Benchmark scoring failed."
}

Write-Host "=== DataCenter-PeakShaving-Benchmark Score ==="

$scoreText -split "`r?`n" |
    Where-Object {
        $_ -match "Peak reduction \[%\]|Normalized benchmark score|Benchmark valid|Final benchmark score"
    } |
    ForEach-Object { Write-Host $_ }

Write-Host "Score log: $scoreLog"


