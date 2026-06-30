@echo off
setlocal
cd /d "%~dp0..\..\.."
echo Starting Qwopus3.6 35B-A3B Coder MTP Q5_K_M 262K server...
echo Endpoint: http://127.0.0.1:8004/v1
echo.
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0start-qwopus36-35b-a3b-coder-mtp-q5-k-m-262k.ps1" %*
