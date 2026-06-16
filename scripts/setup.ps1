param([string]$Python = "")

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ($Python) {
    $pythonCommand = Get-Command $Python -ErrorAction Stop
}
else {
    $pythonCommand = Get-Command python -All |
        Where-Object {
            $_.Version.Major -eq 3 -and
            $_.Version.Minor -ge 11 -and
            $_.Version.Minor -le 13
        } |
        Sort-Object Version -Descending |
        Select-Object -First 1
}
if ($null -eq $pythonCommand) {
    throw "Python 3.11, 3.12 or 3.13 was not found. Pass -Python with an executable path."
}

$pythonExe = $pythonCommand.Source
$pythonVersion = (& $pythonExe -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()
if ($LASTEXITCODE -ne 0) { throw "Cannot run $pythonExe" }
Write-Host "Using Python $pythonVersion at $pythonExe"

function Invoke-Checked([string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Executable failed with exit code $LASTEXITCODE"
    }
}

function Ensure-Venv([string]$Directory) {
    $venv = Join-Path $Directory ".venv"
    $venvPython = Join-Path $venv "Scripts\python.exe"
    if (Test-Path -LiteralPath $venvPython) {
        $venvVersion = (& $venvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()
        if ($venvVersion -ne $pythonVersion) {
            $resolvedVenv = [IO.Path]::GetFullPath($venv)
            if (-not $resolvedVenv.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Unsafe venv path: $resolvedVenv"
            }
            Remove-Item -LiteralPath $resolvedVenv -Recurse -Force
        }
    }
    if (-not (Test-Path -LiteralPath $venvPython)) {
        Invoke-Checked $pythonExe @("-m", "venv", $venv)
    }
    return $venvPython
}

function Install-PythonProject([string]$RelativePath) {
    $project = Join-Path $repoRoot $RelativePath
    $venvPython = Ensure-Venv $project
    Invoke-Checked $venvPython @("-m", "pip", "install", "--upgrade", "pip")
    Invoke-Checked $venvPython @("-m", "pip", "install", "-e", "${project}[dev]")
}

Install-PythonProject "services\knowledge-api"
Install-PythonProject "services\calculator-api"

$previewRoot = Join-Path $repoRoot "preview-codeplace"
$previewPython = Ensure-Venv $previewRoot
Invoke-Checked $previewPython @("-m", "pip", "install", "-r", (Join-Path $previewRoot "requirements-dev.txt"))

Push-Location (Join-Path $repoRoot "apps\frontend-flutter")
try {
    Invoke-Checked (Get-Command flutter).Source @("pub", "get")
}
finally {
    Pop-Location
}

Write-Host "Setup complete. Add the private SQLite or set MED_KB_DB_PATH before full startup."
