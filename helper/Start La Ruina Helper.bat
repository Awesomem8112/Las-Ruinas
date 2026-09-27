@echo off
start "La Ruina Helper Watcher" /min powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0Watch-LaRuina.ps1"
start "LA RUINA HELPER IS RUNNING" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0LaRuinaHelper.ps1"
