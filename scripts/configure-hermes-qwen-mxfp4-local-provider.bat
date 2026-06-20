@echo off
setlocal
cd /d "%~dp0.."
echo Configuring Hermes to use Qwen3.6 35B-A3B MXFP4_MOE MTP locally...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0configure-hermes-qwen-local-provider.ps1" -Name "Qwen3.6 35B-A3B MXFP4 MTP 262K" %*
