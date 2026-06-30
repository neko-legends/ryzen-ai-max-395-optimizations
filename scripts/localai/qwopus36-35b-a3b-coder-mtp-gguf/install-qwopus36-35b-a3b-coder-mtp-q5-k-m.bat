@echo off
setlocal
cd /d "%~dp0..\..\.."
echo Installing Qwopus3.6 35B-A3B Coder MTP Q5_K_M for Hermes...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0install-qwopus36-35b-a3b-coder-mtp-q5-k-m.ps1" %*
