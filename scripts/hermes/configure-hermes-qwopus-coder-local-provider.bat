@echo off
setlocal
cd /d "%~dp0.."
echo Configuring Hermes to use Qwopus3.6 35B-A3B Coder MTP Q5_K_M locally...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0configure-hermes-qwen-local-provider.ps1" -BaseUrl "http://127.0.0.1:8004/v1" -Name "Qwopus3.6 35B-A3B Coder MTP Q5_K_M 262K" %*
