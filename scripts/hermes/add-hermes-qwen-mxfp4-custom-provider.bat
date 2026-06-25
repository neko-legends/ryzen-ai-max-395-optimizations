@echo off
setlocal
cd /d "%~dp0..\.."
echo Adding Qwen3.6 35B-A3B MXFP4_MOE MTP custom provider to Hermes...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0add-hermes-qwen-custom-provider.ps1" -Name "Qwen3.6 35B-A3B MXFP4 MTP 262K" %*
