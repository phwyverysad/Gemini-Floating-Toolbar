@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo  Building Google Gemini Qt6 C++ Desktop Application
echo ===================================================

:: 1. Find and Setup Visual Studio MSVC x64 Environment
set "VS_PATH="
if exist "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat" (
    set "VS_PATH=C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat"
) else if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" (
    set "VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"
)

if "%VS_PATH%"=="" (
    echo [ERROR] Visual Studio x64 compiler environment not found!
    exit /b 1
)

echo [INFO] Initializing MSVC x64 Environment...
call "%VS_PATH%" x64 >nul 2>&1

:: 2. Setup Qt 6.7.3 Environment
set "QT_DIR=C:\Qt\6.7.3\msvc2019_64"
if not exist "%QT_DIR%\bin\qmake.exe" (
    echo [ERROR] Qt 6.7.3 not found at %QT_DIR%!
    exit /b 1
)
set "PATH=%QT_DIR%\bin;%PATH%"

:: 3. Generate Makefile via QMake & Compile with NMake
echo [INFO] Generating Makefile with QMake...
qmake.exe Gemini.pro -spec win32-msvc "CONFIG+=release"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] QMake failed with code %ERRORLEVEL%.
    exit /b %ERRORLEVEL%
)

echo [INFO] Compiling C++ Source Code & QML Resources with NMake...
nmake.exe -f Makefile.Release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] NMake compilation failed with code %ERRORLEVEL%.
    exit /b %ERRORLEVEL%
)

:: 4. Copy Executable to Root & Deploy Qt Dependencies
if exist "release\Gemini.exe" (
    copy /y "release\Gemini.exe" "Gemini.exe" >nul
)

echo [INFO] Deploying Qt Runtime & QML Modules with windeployqt...
windeployqt.exe --qmldir qml --no-translations --compiler-runtime Gemini.exe >nul 2>&1

echo.
echo ===================================================
echo  BUILD SUCCESSFUL: Gemini.exe
echo ===================================================

:: 5. Build Inno Setup Installer (if ISCC exists)
set "ISCC_PATH="
if exist "C:\Users\PC\AppData\Local\Programs\Inno Setup 6\ISCC.exe" (
    set "ISCC_PATH=C:\Users\PC\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
) else if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
)

if not "%ISCC_PATH%"=="" (
    if exist "installer.iss" (
        echo.
        echo [INFO] Packaging Installer using Inno Setup...
        "%ISCC_PATH%" "installer.iss" >nul
        if !ERRORLEVEL! equ 0 (
            echo ===================================================
            echo  PACKAGE SUCCESSFUL: dist\Gemini_Setup.exe
            echo ===================================================
        )
    )
)

exit /b 0
