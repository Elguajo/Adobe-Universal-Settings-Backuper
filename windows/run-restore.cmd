@echo off
set DEST=%1
if "%DEST%"=="" set DEST=%~dp0Backups
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0adobe-backup.ps1" -mode restore -dest "%DEST%"
pause
