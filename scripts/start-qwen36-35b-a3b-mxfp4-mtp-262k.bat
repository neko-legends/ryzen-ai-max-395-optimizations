@echo off
setlocal
cd /d "%~dp0.."
echo Starting Qwen3.6 35B-A3B MXFP4_MOE MTP 262K server...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0start-qwen36-35b-a3b-mxfp4-mtp-262k.ps1" %*
