@echo off
setlocal
set "NODE=\\VBOXSVR\writsrc\portable-node\node.exe"
set "POLICY=\\VBOXSVR\writsrc\generated\mount.mjs"
set "TESTS=\\VBOXSVR\writsrc\generated\mount-tests.js"
set "BRIDGE=\\VBOXSVR\writsrc\source\contrib\native-hosts\runtime\check-bridge.mjs"
set "LOGS=\\VBOXSVR\writlogs"
"%NODE%" --version > "%LOGS%\node-version.txt" 2>&1
echo %ERRORLEVEL% > "%LOGS%\node-version.exit"
"%NODE%" "%TESTS%" > "%LOGS%\model.stdout" 2> "%LOGS%\model.stderr"
echo %ERRORLEVEL% > "%LOGS%\model.exit"
"%NODE%" "%BRIDGE%" "%POLICY%" > "%LOGS%\bridge.stdout" 2> "%LOGS%\bridge.stderr"
echo %ERRORLEVEL% > "%LOGS%\bridge.exit"
endlocal
