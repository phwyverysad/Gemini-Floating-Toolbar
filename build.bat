@echo off
setlocal

powershell -NoProfile -Command "Stop-Process -Name Gemini -Force -ErrorAction SilentlyContinue"

echo ===================================================
echo  Building Google Gemini Qt6 C++ Desktop Application
echo ===================================================

if not defined QT_DIR (
    if exist "C:\Qt\6.7.3\msvc2019_64\bin\qmake.exe" (
        set "QT_DIR=C:\Qt\6.7.3\msvc2019_64"
    )
)

if not defined QT_DIR (
    echo [ERROR] Qt 6 directory not found!
    exit /b 1
)

set "PATH=%QT_DIR%\bin;%PATH%"

set "VS_PATH="
if exist "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat" (
    set "VS_PATH=C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat"
) else if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" (
    set "VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"
)

if "%VS_PATH%"=="" (
    echo [ERROR] Visual Studio vcvarsall.bat not found!
    exit /b 1
)

echo [INFO] Initializing MSVC x64 Environment...
call "%VS_PATH%" x64 >nul 2>&1

echo [INFO] Generating Makefile with QMake...
qmake.exe Gemini.pro -spec win32-msvc "CONFIG+=release"

echo [INFO] Compiling with NMake...
nmake.exe -f Makefile.Release

if exist "release\Gemini.exe" (
    copy /y "release\Gemini.exe" "Gemini.exe" >nul
)

echo [INFO] Running windeployqt...
windeployqt.exe --qmldir qml --no-translations --compiler-runtime Gemini.exe >nul 2>&1

echo.
echo ===================================================
echo  BUILD COMPLETE: Gemini.exe
echo ===================================================

exit /b 0
