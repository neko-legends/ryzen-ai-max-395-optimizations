@echo off
setlocal
cd /d "%~dp0.."
echo Adding Qwopus3.6 35B-A3B Coder MTP Q5_K_M custom provider to Hermes...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0add-hermes-qwen-custom-provider.ps1" -BaseUrl "http://127.0.0.1:8004/v1" -Name "Qwopus3.6 35B-A3B Coder MTP Q5_K_M 262K" %*
