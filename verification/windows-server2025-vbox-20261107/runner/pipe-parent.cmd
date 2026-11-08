@echo off
start "" /b C:\Windows\System32\cmd.exe /d /c C:\writ-stage\pipe-child.cmd
echo PARENT_RETURNING
exit /b 0
