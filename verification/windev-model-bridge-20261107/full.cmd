@echo off
setlocal
"\\VBOXSVR\writsrc\portable-node\node.exe" "\\VBOXSVR\writsrc\generated\full-tests-810e8ee.js" > "\\VBOXSVR\writlogs\full.stdout" 2> "\\VBOXSVR\writlogs\full.stderr"
echo %ERRORLEVEL% > "\\VBOXSVR\writlogs\full.exit"
endlocal
