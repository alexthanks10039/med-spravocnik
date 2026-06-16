$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$installRoot = Join-Path $env:LOCALAPPDATA 'Programs\MedSpravochnik'
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs'))
$resolvedInstallRoot = [IO.Path]::GetFullPath($installRoot)

if (-not $resolvedInstallRoot.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe installation path: $resolvedInstallRoot"
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installRoot 'web') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $installRoot 'logs') -Force | Out-Null

Copy-Item -Path (Join-Path $projectRoot 'build\web\*') -Destination (Join-Path $installRoot 'web') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'windows_desktop_host.py') -Destination (Join-Path $installRoot 'windows_desktop_host.py') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'windows_config.json') -Destination (Join-Path $installRoot 'config.json') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'windows\runner\resources\app_icon.ico') -Destination (Join-Path $installRoot 'MedSpravochnik.ico') -Force

$projectItem = Get-Item -LiteralPath $projectRoot
$resolvedProjectRoot = if ($projectItem.Target) { [string]$projectItem.Target } else { $projectRoot }
$workspaceRoot = Split-Path -Parent $resolvedProjectRoot
$pythonw = Join-Path $workspaceRoot 'MEDICAL KNOWLEDGE BASE\.venv\Scripts\pythonw.exe'
$hostScript = Join-Path $installRoot 'windows_desktop_host.py'
$icon = Join-Path $installRoot 'MedSpravochnik.ico'
$shell = New-Object -ComObject WScript.Shell
$shortcutName = (-join @(
    [char]0x041C, [char]0x0435, [char]0x0434, [char]0x0421,
    [char]0x043F, [char]0x0440, [char]0x0430, [char]0x0432,
    [char]0x043E, [char]0x0447, [char]0x043D, [char]0x0438,
    [char]0x043A
)) + '.lnk'

$shortcutPaths = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) $shortcutName),
    (Join-Path ([Environment]::GetFolderPath('Programs')) $shortcutName)
)

Remove-Item -LiteralPath (Join-Path ([Environment]::GetFolderPath('Desktop')) 'MedSpravochnik.lnk') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path ([Environment]::GetFolderPath('Programs')) 'MedSpravochnik.lnk') -Force -ErrorAction SilentlyContinue

foreach ($shortcutPath in $shortcutPaths) {
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $pythonw
    $shortcut.Arguments = '"' + $hostScript + '"'
    $shortcut.WorkingDirectory = $installRoot
    $shortcut.IconLocation = $icon + ',0'
    $shortcut.Description = 'Medical calculators and clinical protocols'
    $shortcut.Save()
}

Start-Process -FilePath $pythonw -ArgumentList ('"' + $hostScript + '"') -WorkingDirectory $installRoot -WindowStyle Hidden

$deadline = (Get-Date).AddSeconds(90)
do {
    Start-Sleep -Milliseconds 500
    try {
        $appResponse = Invoke-WebRequest -Uri 'http://127.0.0.1:8787/' -UseBasicParsing -TimeoutSec 2
        if ($appResponse.StatusCode -eq 200) { break }
    } catch {
        if ((Get-Date) -ge $deadline) { throw }
    }
} while ((Get-Date) -lt $deadline)

$calculatorHealth = Invoke-RestMethod -Uri 'http://127.0.0.1:8787/calculator/health' -TimeoutSec 60
$knowledgeHealth = Invoke-RestMethod -Uri 'http://127.0.0.1:8787/knowledge/health' -TimeoutSec 60

[PSCustomObject]@{
    InstallPath = $installRoot
    DesktopShortcut = $shortcutPaths[0]
    CalculatorStatus = $calculatorHealth.status
    CalculatorCount = $calculatorHealth.calculators
    KnowledgeStatus = $knowledgeHealth.status
    Version = '0.0.0.01'
}
