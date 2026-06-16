param(
    [switch]$Rebuild,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repositoryRoot = (Resolve-Path (Join-Path $projectRoot '..\..')).Path
$indexPath = Join-Path $projectRoot 'build\web\index.html'
$services = @{
    calculator = @{
        cwd = Join-Path $repositoryRoot 'services\calculator-api'
        python = Join-Path $repositoryRoot 'services\calculator-api\.venv\Scripts\python.exe'
        module = 'src.infrastructure.api.server'
    }
    knowledge = @{
        cwd = Join-Path $repositoryRoot 'services\knowledge-api'
        python = Join-Path $repositoryRoot 'services\knowledge-api\.venv\Scripts\python.exe'
        module = 'medical_kb.api'
    }
}
$sourceRoots = @(
    (Join-Path $projectRoot 'lib'),
    (Join-Path $projectRoot 'web'),
    (Join-Path $projectRoot 'pubspec.yaml')
)

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter is not available in PATH. Install Flutter and restart the terminal.'
}
foreach ($serviceName in @('calculator', 'knowledge')) {
    $service = $services[$serviceName]
    if (-not (Test-Path -LiteralPath $service.cwd -PathType Container)) {
        throw "Backend folder for $serviceName not found: $($service.cwd)"
    }
    if (-not (Test-Path -LiteralPath $service.python -PathType Leaf)) {
        throw "Python virtual environment for $serviceName not found: $($service.python)"
    }
    Push-Location $service.cwd
    try {
        & $service.python -c "import fastapi, uvicorn, $($service.module)" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Dependencies for $serviceName are incomplete. Reinstall that backend virtual environment."
        }
    }
    finally {
        Pop-Location
    }
}

$databaseAvailable = if ($env:MED_KB_DB_PATH) {
    Test-Path -LiteralPath $env:MED_KB_DB_PATH -PathType Leaf
} else {
    Push-Location $services.knowledge.cwd
    try {
        & $services.knowledge.python -c 'import sys; from medical_kb.config import Settings; sys.exit(0 if Settings.from_env().database_path.is_file() else 2)'
        $LASTEXITCODE -eq 0
    }
    finally {
        Pop-Location
    }
}
if (-not $databaseAvailable) {
    throw 'Medical SQLite database not found. Set MED_KB_DB_PATH to the correct file.'
}

if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.dart_tool\package_config.json'))) {
    Push-Location $projectRoot
    try {
        flutter pub get
        if ($LASTEXITCODE -ne 0) {
            throw "flutter pub get failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

$needsBuild = $Rebuild -or -not (Test-Path -LiteralPath $indexPath)
if (-not $needsBuild) {
    $buildTime = (Get-Item -LiteralPath $indexPath).LastWriteTimeUtc
    foreach ($sourceRoot in $sourceRoots) {
        if (Test-Path -LiteralPath $sourceRoot -PathType Leaf) {
            if ((Get-Item -LiteralPath $sourceRoot).LastWriteTimeUtc -gt $buildTime) {
                $needsBuild = $true
                break
            }
            continue
        }
        $newerSource = Get-ChildItem -LiteralPath $sourceRoot -Recurse -File |
            Where-Object { $_.LastWriteTimeUtc -gt $buildTime } |
            Select-Object -First 1
        if ($null -ne $newerSource) {
            $needsBuild = $true
            break
        }
    }
}

Push-Location $projectRoot
try {
    if ($needsBuild) {
        Write-Host 'Building Flutter web application...'
        flutter build web --release `
            --dart-define=CALCULATOR_API_URL=/calculator `
            --dart-define=KNOWLEDGE_API_URL=/knowledge
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter build failed with exit code $LASTEXITCODE"
        }
    }

    if ($NoBrowser) {
        $env:MED_APP_NO_BROWSER = '1'
    }
    Write-Host 'Starting medical reference at http://127.0.0.1:8787'
    & (Get-Command python).Source (Join-Path $projectRoot 'tools\windows_desktop_host.py')
}
finally {
    Pop-Location
}
