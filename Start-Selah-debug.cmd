@echo off
rem Shows Selah with a visible PowerShell window so any error message stays on screen.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Selah.ps1"
pause
