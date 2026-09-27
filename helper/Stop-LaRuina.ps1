# Stops the helper window and the watcher, and removes the login shortcut.

$ErrorActionPreference = "Continue"

$helperDir = $PSScriptRoot
if (-not $helperDir) {
    $helperDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

foreach ($name in @("watcher.lock", "helper.lock")) {
    $lock = Join-Path $helperDir $name
    if (-not (Test-Path -LiteralPath $lock)) {
        continue
    }
    $pidText = Get-Content -LiteralPath $lock -ErrorAction SilentlyContinue | Select-Object -First 1
    $oldPid = 0
    if ([int]::TryParse($pidText, [ref]$oldPid)) {
        Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue
}

$shortcut = Join-Path ([Environment]::GetFolderPath("Startup")) "La Ruina Helper.lnk"
if (Test-Path -LiteralPath $shortcut) {
    Remove-Item -LiteralPath $shortcut -Force
}

Unregister-ScheduledTask -TaskName "La Ruina Helper" -Confirm:$false -ErrorAction SilentlyContinue
