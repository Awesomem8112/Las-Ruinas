# Starts the La Ruina helper window when Hearts of Iron IV is running
# with La Ruina enabled. Closing the helper window leaves it off until
# the game is started again.

$ErrorActionPreference = "Continue"

$helperDir = $PSScriptRoot
if (-not $helperDir) {
    $helperDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$laRuinaDir = Split-Path -Parent $helperDir
$modDir = Split-Path -Parent $laRuinaDir
$docsDir = Split-Path -Parent $modDir
$dlcLoadPath = Join-Path $docsDir "dlc_load.json"
$watcherScript = Join-Path $helperDir "Watch-LaRuina.ps1"
$helperScript = Join-Path $helperDir "LaRuinaHelper.ps1"
$watcherLock = Join-Path $helperDir "watcher.lock"
$helperLock = Join-Path $helperDir "helper.lock"
$powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

function Test-TrackedProcess {
    param([string]$LockFile)
    if (-not (Test-Path -LiteralPath $LockFile)) {
        return $false
    }
    $pidText = Get-Content -LiteralPath $LockFile -ErrorAction SilentlyContinue | Select-Object -First 1
    $oldPid = 0
    if (-not [int]::TryParse($pidText, [ref]$oldPid)) {
        return $false
    }
    if ($oldPid -eq $PID) {
        return $false
    }
    $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
    return ($null -ne $proc -and $proc.ProcessName -eq "powershell")
}

if (Test-TrackedProcess -LockFile $watcherLock) {
    exit 0
}

Set-Content -LiteralPath $watcherLock -Value $PID -Encoding ascii

function Install-StartupShortcut {
    $startup = [Environment]::GetFolderPath("Startup")
    $shortcutPath = Join-Path $startup "La Ruina Helper.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $powershell
    $shortcut.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$watcherScript`""
    $shortcut.WorkingDirectory = $helperDir
    $shortcut.WindowStyle = 7
    $shortcut.Description = "Opens the La Ruina helper when Hearts of Iron IV starts with La Ruina enabled."
    $shortcut.Save()
}

function Test-LaRuinaEnabled {
    $text = ""
    if (Test-Path -LiteralPath $dlcLoadPath) {
        $text = [string](Get-Content -LiteralPath $dlcLoadPath -Raw -ErrorAction SilentlyContinue)
    }
    $running = Get-CimInstance Win32_Process -Filter "Name = 'hoi4.exe'" -ErrorAction SilentlyContinue
    foreach ($proc in $running) {
        $text += "`n" + [string]$proc.CommandLine
    }
    return ($text -match "la_ruina\.mod" -or $text -match "la_ruina_helper_test\.mod")
}

function Start-HelperWindow {
    $arguments = "-NoProfile -STA -ExecutionPolicy Bypass -File `"$helperScript`""
    Start-Process -FilePath $powershell -ArgumentList $arguments | Out-Null
}

function Remove-WatcherLock {
    if (-not (Test-Path -LiteralPath $watcherLock)) {
        return
    }
    $pidText = Get-Content -LiteralPath $watcherLock -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pidText -eq "$PID") {
        Remove-Item -LiteralPath $watcherLock -Force -ErrorAction SilentlyContinue
    }
}

Install-StartupShortcut

$servedPid = 0
try {
    while ($true) {
        try {
            $game = Get-Process -Name "hoi4" -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $game) {
                $servedPid = 0
            }
            elseif ($game.Id -ne $servedPid -and (Test-LaRuinaEnabled)) {
                $helperUp = Test-TrackedProcess -LockFile $helperLock
                if (-not $helperUp) {
                    Start-HelperWindow
                }
                $servedPid = $game.Id
            }
        }
        catch {
        }
        Start-Sleep -Seconds 2
    }
}
finally {
    Remove-WatcherLock
}
