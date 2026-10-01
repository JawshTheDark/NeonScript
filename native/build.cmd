@echo off
rem ---------------------------------------------------------------------------
rem  Builds neonui.dll (32-bit - mIRC is a 32-bit program) with Visual Studio's C++ compiler and writes its
rem  SHA-256 next to the pack so NeonScript can verify it before it ever calls it.
rem
rem  Needs: Visual Studio / Build Tools with "Desktop development with C++" and the Microsoft.Web.WebView2
rem         NuGet package (headers + WebView2LoaderStatic.lib).  Set WEBVIEW2_SDK to its folder, or leave it
rem         unset to use the newest copy in %USERPROFILE%\.nuget\packages\microsoft.web.webview2.
rem  Run:   native\build.cmd
rem ---------------------------------------------------------------------------
setlocal EnableDelayedExpansion
set "HERE=%~dp0"
set "ROOT=%HERE%.."
set "VCVARS="

for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul`) do set "VSROOT=%%i"
if defined VSROOT set "VCVARS=%VSROOT%\VC\Auxiliary\Build\vcvarsamd64_x86.bat"
if not exist "%VCVARS%" (
  for %%D in ("%ProgramFiles%\Microsoft Visual Studio\18\Community" "%ProgramFiles%\Microsoft Visual Studio\2022\Community" "%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools" "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools" "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools") do (
    if exist "%%~D\VC\Auxiliary\Build\vcvarsamd64_x86.bat" set "VCVARS=%%~D\VC\Auxiliary\Build\vcvarsamd64_x86.bat"
  )
)
if not exist "%VCVARS%" (
  echo Could not find the Visual Studio C++ tools. Install "Desktop development with C++" and retry.
  exit /b 1
)

if not defined WEBVIEW2_SDK (
  for /f "delims=" %%d in ('dir /b /ad /o-n "%USERPROFILE%\.nuget\packages\microsoft.web.webview2" 2^>nul') do (
    if not defined WEBVIEW2_SDK set "WEBVIEW2_SDK=%USERPROFILE%\.nuget\packages\microsoft.web.webview2\%%d"
  )
)
if not exist "%WEBVIEW2_SDK%\build\native\include\WebView2.h" (
  echo Could not find the WebView2 SDK. Install the Microsoft.Web.WebView2 NuGet package or set WEBVIEW2_SDK.
  exit /b 1
)

call "%VCVARS%" >nul
if errorlevel 1 exit /b 1

pushd "%HERE%"
cl /nologo /LD /O2 /MT /EHsc /std:c++17 /W3 /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN /I"%WEBVIEW2_SDK%\build\native\include" neonui.cpp /Fe:neonui.dll /link /DEF:neonui.def /LIBPATH:"%WEBVIEW2_SDK%\build\native\x86" WebView2LoaderStatic.lib user32.lib gdi32.lib gdiplus.lib comctl32.lib ole32.lib oleaut32.lib shell32.lib advapi32.lib dwmapi.lib version.lib shlwapi.lib
if errorlevel 1 ( popd & exit /b 1 )
del /q neonui.obj neonui.lib neonui.exp >nul 2>&1

copy /y neonui.dll "%ROOT%\neonui.dll" >nul
del /q neonui.dll >nul 2>&1
set "SUM="
for /f "skip=1 delims=" %%h in ('certutil -hashfile "%ROOT%\neonui.dll" SHA256') do (
  if not defined SUM set "SUM=%%h"
)
set "SUM=%SUM: =%"
> "%ROOT%\data\neonui.sha256" echo %SUM%
echo.
echo Built %ROOT%\neonui.dll
echo SHA-256: %SUM%
popd
endlocal
