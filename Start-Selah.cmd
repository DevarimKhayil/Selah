@echo off
rem Starts Selah with no console window. conhost --headless keeps Windows Terminal from opening.
rem For a launch with no flash at all, use the "Selah" shortcut in this folder or in the Start menu.
start "" "%SystemRoot%\System32\conhost.exe" --headless "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File "%~dp0Selah.ps1"
exit /b
