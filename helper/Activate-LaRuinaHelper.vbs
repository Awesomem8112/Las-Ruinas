' Scheduled task host. wscript.exe has no console, and window style 0
' creates the PowerShell check already hidden, so nothing flashes.
Option Explicit

Dim fso, shell, helperDir, ps1
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("Wscript.Shell")
helperDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = helperDir & "\Activate-LaRuinaHelper.ps1"
shell.Run "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & ps1 & """", 0, True
