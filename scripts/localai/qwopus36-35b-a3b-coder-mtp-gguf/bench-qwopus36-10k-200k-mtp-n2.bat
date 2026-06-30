@echo off
setlocal
cd /d "%~dp0..\..\.."
echo Running Qwopus3.6 35B-A3B Coder MTP Q5_K_M 10K + 200K benchmark...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bench-qwopus36-10k-200k-mtp-n2.ps1" %*
pause
