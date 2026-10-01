@echo off
rem ---------------------------------------------------------------------------
rem  Builds neonsec.dll (32-bit - mIRC is a 32-bit program) with Visual Studio's
rem  C compiler and writes its SHA-256 next to the pack so NeonScript can verify it.
rem
rem  Needs: Visual Studio / Build Tools with "Desktop development with C++"
rem  Run:   tools\dll\build.cmd
rem ---------------------------------------------------------------------------
setlocal
set "HERE=%~dp0"
set "ROOT=%HERE%..\.."
set "VCVARS="

for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul`) do set "VSROOT=%%i"
if defined VSROOT set "VCVARS=%VSROOT%\VC\Auxiliary\Build\vcvarsamd64_x86.bat"
if not exist "%VCVARS%" (
  for %%D in ("%ProgramFiles%\Microsoft Visual Studio\18\Community" "%ProgramFiles%\Microsoft Visual Studio\2022\Community" "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools" "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools") do (
    if exist "%%~D\VC\Auxiliary\Build\vcvarsamd64_x86.bat" set "VCVARS=%%~D\VC\Auxiliary\Build\vcvarsamd64_x86.bat"
  )
)
if not exist "%VCVARS%" (
  echo Could not find the Visual Studio C++ tools. Install "Desktop development with C++" and retry.
  exit /b 1
)

call "%VCVARS%" >nul
if errorlevel 1 exit /b 1

pushd "%HERE%"
cl /nologo /LD /O1 /GS- /Zl /W3 neonsec.c /Fe:neonsec.dll /link /NODEFAULTLIB /DLL /ENTRY:DllMain /DEF:neonsec.def kernel32.lib crypt32.lib
if errorlevel 1 ( popd & exit /b 1 )
del /q neonsec.obj neonsec.lib neonsec.exp >nul 2>&1

copy /y neonsec.dll "%ROOT%\neonsec.dll" >nul
for /f "skip=1 delims=" %%h in ('certutil -hashfile "%ROOT%\neonsec.dll" SHA256') do (
  if not defined SUM set "SUM=%%h"
)
set "SUM=%SUM: =%"
> "%ROOT%\data\neonsec.sha256" echo %SUM%
echo.
echo Built %ROOT%\neonsec.dll
echo SHA-256: %SUM%
popd
endlocal
