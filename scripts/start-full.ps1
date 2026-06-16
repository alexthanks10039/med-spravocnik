$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
& (Join-Path $repoRoot "apps\frontend-flutter\start_project.ps1") @args
