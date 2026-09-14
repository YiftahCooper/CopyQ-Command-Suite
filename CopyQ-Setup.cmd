@echo off
setlocal
where pwsh.exe >nul 2>nul
if errorlevel 1 (
  echo PowerShell 7.2 or newer is required. Install it from:
  echo https://github.com/PowerShell/PowerShell
  echo Then run CopyQ-Setup.cmd again. Nothing has been changed.
  pause
  exit /b 1
)
pwsh.exe -NoLogo -NoProfile -STA -File "%~dp0scripts\Setup-CopyQ.ps1"
if errorlevel 1 pause
