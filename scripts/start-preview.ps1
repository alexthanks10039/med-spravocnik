param([int]$Port = 8787)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$previewRoot = Join-Path $repoRoot "preview-codeplace"
$previewPython = Join-Path $previewRoot ".venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $previewPython)) {
    $previewPython = (Get-Command python).Source
}
& $previewPython -m uvicorn app:app --app-dir $previewRoot --host 0.0.0.0 --port $Port
