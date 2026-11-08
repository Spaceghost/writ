@echo off
echo started > C:\writ-stage\process-smoke-04\child-started.txt
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -NonInteractive -Command "Start-Sleep -Seconds 12"
echo alive-after-parent > C:\writ-stage\process-smoke-04\child-late.txt
echo CHILD_DELAYED_STDOUT
echo attempted > C:\writ-stage\process-smoke-04\child-write-attempted.txt
exit /b 0
