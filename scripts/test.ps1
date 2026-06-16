$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Invoke-Checked([string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Executable failed with exit code $LASTEXITCODE"
    }
}

$knowledgePython = Join-Path $repoRoot "services\knowledge-api\.venv\Scripts\python.exe"
$calculatorPython = Join-Path $repoRoot "services\calculator-api\.venv\Scripts\python.exe"
$previewPython = Join-Path $repoRoot "preview-codeplace\.venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $previewPython)) {
    $previewPython = (Get-Command python).Source
}

Invoke-Checked $knowledgePython @("-m", "pytest", "-q", (Join-Path $repoRoot "services\knowledge-api\tests"))
Invoke-Checked $calculatorPython @(
    "-m", "pytest", "-q",
    (Join-Path $repoRoot "services\calculator-api\tests"),
    "--ignore=$(Join-Path $repoRoot 'services\calculator-api\tests\test_hf_benchmark_dataset.py')"
)
Invoke-Checked $previewPython @("-m", "pytest", "-q", (Join-Path $repoRoot "preview-codeplace\test_preview.py"))

Push-Location (Join-Path $repoRoot "apps\frontend-flutter")
try {
    Invoke-Checked (Get-Command dart).Source @("analyze", "lib", "test")
    Invoke-Checked (Get-Command flutter).Source @("test")
}
finally {
    Pop-Location
}

Invoke-Checked (Get-Command git).Source @("-C", $repoRoot, "diff", "--check")
