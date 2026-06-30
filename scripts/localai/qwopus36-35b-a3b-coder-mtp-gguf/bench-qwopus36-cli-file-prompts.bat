@echo off
setlocal
cd /d "%~dp0..\..\.."
echo Running Qwopus3.6 35B-A3B Coder MTP Q5_K_M file-prompt benchmark...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bench-qwopus36-cli-file-prompts.ps1" %*
pause
