# Runs from Task Scheduler, then exits.
# If Hearts of Iron IV is open with La Ruina enabled, it opens the helper window.
# No shell is left running.

$ErrorActionPreference = "Continue"

$helperDir = $PSScriptRoot
if (-not $helperDir) {
    $helperDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$laRuinaDir = Split-Path -Parent $helperDir
$modDir = Split-Path -Parent $laRuinaDir
$docsDir = Split-Path -Parent $modDir
$dlcLoadPath = Join-Path $docsDir "dlc_load.json"
$helperScript = Join-Path $helperDir "LaRuinaHelper.ps1"
$helperLock = Join-Path $helperDir "helper.lock"
$powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

function Test-HelperRunning {
    if (-not (Test-Path -LiteralPath $helperLock)) {
        return $false
    }
    $pidText = Get-Content -LiteralPath $helperLock -ErrorAction SilentlyContinue | Select-Object -First 1
    $oldPid = 0
    if (-not [int]::TryParse($pidText, [ref]$oldPid)) {
        return $false
    }
    $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
    return ($null -ne $proc -and $proc.ProcessName -eq "powershell")
}

$game = Get-Process -Name "hoi4" -ErrorAction SilentlyContinue | Select-Object -First 1
$enabled = $false
if (Test-Path -LiteralPath $dlcLoadPath) {
    $text = [string](Get-Content -LiteralPath $dlcLoadPath -Raw -ErrorAction SilentlyContinue)
    $enabled = $text -match "la_ruina\.mod" -or $text -match "la_ruina_helper_test\.mod"
}

if (-not $game -or -not $enabled -or (Test-HelperRunning)) {
    exit 0
}

# Created by WMI so this console is hidden at creation and is not part of the task job.
$command = "`"$powershell`" -NoProfile -NonInteractive -WindowStyle Hidden -STA -ExecutionPolicy Bypass -File `"$helperScript`""
$startup = ([wmiclass]"Win32_ProcessStartup").CreateInstance()
$startup.ShowWindow = 0
([wmiclass]"Win32_Process").Create($command, $helperDir, $startup) | Out-Null

exit 0
