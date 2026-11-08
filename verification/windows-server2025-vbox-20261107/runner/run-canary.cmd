@echo off
rem Process-only execution policy override; no machine or user policy change.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File C:\writ-stage\run-canary.ps1
set "writ_exit=%ERRORLEVEL%"
echo Writ public-canary runner exit: %writ_exit%
echo Results remain in C:\writ-stage\results
pause
exit /b %writ_exit%
