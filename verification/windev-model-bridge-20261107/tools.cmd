@echo off
(
  echo --- Windows ---
  ver
  echo --- Node ---
  where node.exe
  node.exe --version
  echo --- CMake ---
  where cmake.exe
  cmake.exe --version
  echo --- Visual Studio ---
  if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -all -products * -property installationPath
  echo --- WinFsp ---
  if exist "%ProgramFiles(x86)%\WinFsp\bin\winfsp-x64.dll" echo WinFsp runtime present at default location
  if not exist "%ProgramFiles(x86)%\WinFsp\bin\winfsp-x64.dll" echo WinFsp runtime absent at default location
  echo --- end inventory ---
) > "\\VBOXSVR\writlogs\tools.txt" 2>&1
