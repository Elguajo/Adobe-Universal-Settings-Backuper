@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0adobe-backup.ps1" -mode backup -dest "%~dp0Backups"
pause
