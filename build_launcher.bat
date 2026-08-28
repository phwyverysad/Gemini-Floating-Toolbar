@echo off
setlocal

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

call "%VS_PATH%" x64 >nul 2>&1

if not exist "obj" mkdir obj
if not exist "dist" mkdir dist

echo [INFO] Compiling Resource for Single-File Launcher...
rc.exe /fo obj\launcher.res resources\launcher.rc
if %ERRORLEVEL% neq 0 (
    echo [ERROR] rc.exe failed!
    exit /b 1
)

echo [INFO] Compiling Standalone Single-File Executable...
cl.exe /nologo /O2 /MD /std:c++20 /utf-8 /EHsc /guard:cf src\SingleFileLauncher.cpp obj\launcher.res /link /SUBSYSTEM:WINDOWS /DYNAMICBASE /NXCOMPAT /HIGHENTROPYVA /OPT:REF /OPT:ICF /guard:cf /OUT:dist\Gemini_Portable.exe
if %ERRORLEVEL% neq 0 (
    echo [ERROR] cl.exe failed!
    exit /b 1
)

echo [SUCCESS] dist\Gemini_Portable.exe created successfully!
exit /b 0
