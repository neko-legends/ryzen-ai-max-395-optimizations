@echo off
setlocal

set "SRC=%~dp0llama-cli-launcher.cpp"
set "OUT=%USERPROFILE%\.unsloth\llama.cpp\build\bin\Release\llama-cli.exe"
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

if not exist "%SRC%" (
  echo Missing source: "%SRC%"
  exit /b 1
)

if not exist "%USERPROFILE%\.unsloth\llama.cpp\build\bin\Release\llama-cli-impl.dll" (
  echo Missing llama-cli-impl.dll under the Unsloth llama.cpp Release folder.
  exit /b 1
)

if not exist "%VSWHERE%" (
  echo Could not find vswhere.exe. Install Visual Studio Build Tools with C++ tools.
  exit /b 1
)

for /f "usebackq tokens=*" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%I"

if "%VSINSTALL%"=="" (
  echo Could not find Visual Studio C++ Build Tools.
  exit /b 1
)

call "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1

cl /nologo /O2 /EHsc /std:c++17 /Fo:"%TEMP%\llama-cli-launcher.obj" /Fe:"%OUT%" "%SRC%"
if errorlevel 1 exit /b 1

echo Built "%OUT%"
