@echo off
setlocal

set MODE=%1
set DEST=%2

if /I "%MODE%"=="backup" goto do_backup
if /I "%MODE%"=="restore" goto do_restore

echo Adobe Universal Settings Backuper
echo.
echo 1^) Backup
echo 2^) Restore
echo.
set /p CHOICE=Select (1/2): 

if "%CHOICE%"=="1" goto do_backup
if "%CHOICE%"=="2" goto do_restore_prompt

echo Invalid choice.
goto end

:do_backup
call "%~dp0windows\run-backup.cmd"
goto end

:do_restore_prompt
set /p DEST=Enter full path to backup folder: 
:do_restore
if "%DEST%"=="" (
  echo Please specify backup folder path for restore.
  goto end
)
call "%~dp0windows\run-restore.cmd" "%DEST%"
goto end

:end
endlocal
