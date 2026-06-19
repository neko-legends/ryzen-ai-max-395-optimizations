@echo off
setlocal
cd /d "%~dp0.."
echo Configuring Hermes to use the local Qwen OpenAI-compatible endpoint...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0configure-hermes-qwen-local-provider.ps1" %*
