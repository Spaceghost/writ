@echo off
setlocal
(
  echo Writ Windows read-only prerequisite inventory
  echo Source revision: 9131a2a77c89905e6e69e1f793d369a2128ea165
  ver
  echo --- elevation ---
  powershell.exe -NoProfile -Command "$p = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()); 'Elevated administrator: ' + $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)"
  echo --- Node ---
  where node.exe
  node.exe --version
  echo --- CMake ---
  where cmake.exe
  cmake.exe --version
  echo --- Visual Studio installation ---
  if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -all -products * -property installationPath
  echo --- WinFsp runtime ---
  if exist "%ProgramFiles(x86)%\WinFsp\bin\winfsp-x64.dll" powershell.exe -NoProfile -Command "(Get-Item -LiteralPath '${env:ProgramFiles(x86)}\WinFsp\bin\winfsp-x64.dll').VersionInfo.FileVersion"
  if not exist "%ProgramFiles(x86)%\WinFsp\bin\winfsp-x64.dll" echo WinFsp runtime not found at default location
  echo --- end inventory ---
) > "\\VBOXSVR\writlogs\inventory.txt" 2>&1
endlocal
