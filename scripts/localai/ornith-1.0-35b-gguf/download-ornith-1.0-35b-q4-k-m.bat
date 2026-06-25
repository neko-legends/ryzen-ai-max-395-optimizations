@echo off
setlocal
cd /d "%~dp0..\..\.."
echo Downloading DeepReinforce Ornith 1.0 35B GGUF Q4_K_M...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0download-ornith-1.0-35b-q4-k-m.ps1" %*
