@echo off
setlocal
cd /d "%~dp0..\.."
echo Adding Qwen as a saved Hermes custom provider...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0add-hermes-qwen-custom-provider.ps1" %*
