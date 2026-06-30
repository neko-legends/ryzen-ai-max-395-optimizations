@echo off
setlocal
cd /d "%~dp0..\..\.."
echo Downloading Qwopus3.6 35B-A3B Coder MTP Q5_K_M...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0download-qwopus36-35b-a3b-coder-mtp-q5-k-m.ps1" %*
