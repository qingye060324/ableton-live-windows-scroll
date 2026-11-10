$ErrorActionPreference = 'Stop'

$taskAhkExe = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$taskSource = Join-Path $PSScriptRoot 'AbletonLive12-WheelLines.ahk'
$taskInstallDir = Join-Path $env:LOCALAPPDATA 'AbletonLive12WheelLines'
$taskInstalledScript = Join-Path $taskInstallDir 'AbletonLive12-WheelLines.ahk'
$taskStartupDir = [Environment]::GetFolderPath('Startup')
$taskShortcutPath = Join-Path $taskStartupDir 'Ableton Live 12 Wheel Lines.lnk'

if (-not (Test-Path -LiteralPath $taskAhkExe)) {
    throw 'AutoHotkey v2 x64 was not found in C:\Program Files\AutoHotkey\v2.'
}
if (-not (Test-Path -LiteralPath $taskSource)) {
    throw 'Keep this installer beside AbletonLive12-WheelLines.ahk.'
}

New-Item -ItemType Directory -Path $taskInstallDir -Force | Out-Null
Copy-Item -LiteralPath $taskSource -Destination $taskInstalledScript -Force

$taskShell = New-Object -ComObject WScript.Shell
$taskShortcut = $taskShell.CreateShortcut($taskShortcutPath)
$taskShortcut.TargetPath = $taskAhkExe
$taskShortcut.Arguments = '"' + $taskInstalledScript + '"'
$taskShortcut.WorkingDirectory = $taskInstallDir
$taskShortcut.Description = 'Live 12: normal 5 lines; Ctrl/Alt held = 1 line; Shift unchanged'
$taskShortcut.IconLocation = $taskAhkExe + ',0'
$taskShortcut.Save()

Start-Process -FilePath $taskAhkExe -ArgumentList @('/ErrorStdOut', ('"' + $taskInstalledScript + '"')) -WorkingDirectory $taskInstallDir -WindowStyle Hidden
[pscustomobject]@{
    InstalledScript = $taskInstalledScript
    StartupShortcut = $taskShortcutPath
    AutoHotkey = $taskAhkExe
}
