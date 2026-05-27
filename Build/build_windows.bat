@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM CYCommon Windows Build Script
REM ============================================================
REM BuildType   : Debug | Release  (default: Release)
REM LibType     : Static | Shared  (default: Static)
REM TargetArch   : x64 | x86        (default: x64)
REM CrtType     : MD | MT | MDD | MTD (default: MD)
REM ============================================================

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "SOURCE_DIR=%SCRIPT_DIR%\.."

REM ---------- Parse arguments ----------
set "BUILD_TYPE=Release"
set "LIB_TYPE=Static"
set "TARGET_ARCH=x64"
set "CRT_TYPE=MD"

if not "%~1"=="" (
    set "BUILD_TYPE=%~1"
    if /i "%~1"=="debug"   set "BUILD_TYPE=Debug"
    if /i "%~1"=="release" set "BUILD_TYPE=Release"
)
if not "%~2"=="" (
    set "LIB_TYPE=%~2"
    if /i "%~2"=="shared"  set "LIB_TYPE=Shared"
    if /i "%~2"=="static"  set "LIB_TYPE=Static"
)
if not "%~3"=="" (
    set "TARGET_ARCH=%~3"
)
if not "%~4"=="" (
    set "CRT_TYPE=%~4"
)

REM ---------- Normalize BUILD_TYPE ----------
if /i "%BUILD_TYPE%"=="debug"   set "BUILD_TYPE=Debug"
if /i "%BUILD_TYPE%"=="release" set "BUILD_TYPE=Release"

REM ---------- Normalize LIB_TYPE ----------
if /i "%LIB_TYPE%"=="shared" set "LIB_TYPE=Shared"
if /i "%LIB_TYPE%"=="static" set "LIB_TYPE=Static"

REM ---------- Validate BUILD_TYPE ----------
if not "%BUILD_TYPE%"=="Debug" if not "%BUILD_TYPE%"=="Release" (
    echo ERROR: BUILD_TYPE must be Debug or Release, got "%BUILD_TYPE%"
    exit /b 1
)

REM ---------- Validate LIB_TYPE ----------
if not "%LIB_TYPE%"=="Static" if not "%LIB_TYPE%"=="Shared" (
    echo ERROR: LIB_TYPE must be Static or Shared, got "%LIB_TYPE%"
    exit /b 1
)

REM ---------- Validate TARGET_ARCH ----------
if not "%TARGET_ARCH%"=="x64" if not "%TARGET_ARCH%"=="x86" if not "%TARGET_ARCH%"=="Win32" (
    echo ERROR: TARGET_ARCH must be x64 or x86, got "%TARGET_ARCH%"
    exit /b 1
)
if "%TARGET_ARCH%"=="Win32" set "TARGET_ARCH=x86"

REM ---------- Validate CRT_TYPE ----------
if /i "%CRT_TYPE%"=="MDD" set "CRT_TYPE=MDD"
if /i "%CRT_TYPE%"=="MTD" set "CRT_TYPE=MTD"
if /i "%CRT_TYPE%"=="MD"  set "CRT_TYPE=MD"
if /i "%CRT_TYPE%"=="MT"  set "CRT_TYPE=MT"

if not "%CRT_TYPE%"=="MD" if not "%CRT_TYPE%"=="MT" if not "%CRT_TYPE%"=="MDD" if not "%CRT_TYPE%"=="MTD" (
    echo ERROR: CRT_TYPE must be MD, MT, MDD, or MTD, got "%CRT_TYPE%"
    exit /b 1
)

REM ---------- Auto-fix CRT for build type ----------
REM Release builds use base CRT (MD/MT), Debug builds use D suffix (MDD/MTD)
if "%BUILD_TYPE%"=="Release" (
    if "%CRT_TYPE%"=="MDD" set "CRT_TYPE=MD"
    if "%CRT_TYPE%"=="MTD" set "CRT_TYPE=MT"
)
if "%BUILD_TYPE%"=="Debug" (
    if "%CRT_TYPE%"=="MD"  set "CRT_TYPE=MDD"
    if "%CRT_TYPE%"=="MT"  set "CRT_TYPE=MTD"
)

REM ---------- Derive CMake generator ----------
if "%TARGET_ARCH%"=="x86" (
    set "VSCMD_ARCH=x86"
    set "CMAKE_GEN_ARCH=x86"
) else (
    set "VSCMD_ARCH=x64"
    set "CMAKE_GEN_ARCH=x64"
)

echo ========================================
echo CYCommon Windows Build
echo ========================================
echo   Build Type  : %BUILD_TYPE%
echo   Library Type: %LIB_TYPE%
echo   Architecture: %TARGET_ARCH%
echo   CRT         : %CRT_TYPE%
echo ========================================

REM ---------- Find Visual Studio ----------
set "VS_FOUND=0"
set "VS_DIR="

where vswhere >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    for /f "tokens=*" %%i in ('vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath') do (
        set "VS_DIR=%%i"
        set "VS_FOUND=1"
    )
)

if "%VS_FOUND%"=="0" (
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Community"     set "VS_DIR=C:\Program Files\Microsoft Visual Studio\2022\Community"     && set "VS_FOUND=1"
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional" set "VS_DIR=C:\Program Files\Microsoft Visual Studio\2022\Professional" && set "VS_FOUND=1"
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise"    set "VS_DIR=C:\Program Files\Microsoft Visual Studio\2022\Enterprise"    && set "VS_FOUND=1"
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Preview"      set "VS_DIR=C:\Program Files\Microsoft Visual Studio\2022\Preview"      && set "VS_FOUND=1"
    if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community"     set "VS_DIR=C:\Program Files (x86)\Microsoft Visual Studio\2019\Community"     && set "VS_FOUND=1"
    if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional"   set "VS_DIR=C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional"   && set "VS_FOUND=1"
    if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise"    set "VS_DIR=C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise"    && set "VS_FOUND=1"
)

if "%VS_FOUND%"=="0" (
    echo ERROR: Visual Studio not found. Please install Visual Studio 2019 or 2022.
    exit /b 1
)

echo Found Visual Studio at: %VS_DIR%

REM ---------- Configure build environment ----------
set "VSCMDDIR=%VS_DIR%\Common7\Tools\VsDevCmd.bat"
if not exist "%VSCMDDIR%" (
    set "VSCMDDIR=%VS_DIR%\VC\Auxiliary\Build\vcvarsall.bat"
)

if exist "%VSCMDDIR%" (
    call "%VSCMDDIR%" %VSCMD_ARCH% >nul 2>&1
) else (
    echo WARNING: VsDevCmd.bat not found at "%VSCMDDIR%"
    echo You may need to manually configure the Visual Studio environment.
)

REM ---------- Create output directory ----------
if not exist "%SOURCE_DIR%\Bin\Windows\%TARGET_ARCH%\%CRT_TYPE%\%BUILD_TYPE%" (
    mkdir "%SOURCE_DIR%\Bin\Windows\%TARGET_ARCH%\%CRT_TYPE%\%BUILD_TYPE%" 2>nul
)

REM ---------- Create build directory ----------
set "BUILD_DIR=%SCRIPT_DIR%out\Windows\%TARGET_ARCH%\%LIB_TYPE%\%CRT_TYPE%\%BUILD_TYPE%"
if not exist "%BUILD_DIR%" (
    mkdir "%BUILD_DIR%" 2>nul
    for /f "tokens=*" %%d in ("%BUILD_DIR%") do mkdir "%%~fd\." >nul 2>&1
)

echo Build directory: %BUILD_DIR%
echo.

REM ---------- Configure CMake ----------
set "SHARED_FLAG=-DBUILD_SHARED_LIBS=OFF"
if /i "%LIB_TYPE%"=="Shared" set "SHARED_FLAG=-DBUILD_SHARED_LIBS=ON"

cmake -S "%SCRIPT_DIR%" ^
      -B "%BUILD_DIR%" ^
      -G "Visual Studio 17 2022" ^
      -A %CMAKE_GEN_ARCH% ^
      -DCMAKE_BUILD_TYPE=%BUILD_TYPE% ^
      %SHARED_FLAG% ^
      -DWINDOWS_RUNTIME=%CRT_TYPE% ^
      -DCYCOMMON_OUTPUT_BASE_DIR="%SOURCE_DIR%\Bin\Windows\%TARGET_ARCH%\%CRT_TYPE%"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: CMake configuration failed.
    exit /b 1
)

REM ---------- Build ----------
echo.
echo Building CYCommon...

cmake --build "%BUILD_DIR%" --parallel --config %BUILD_TYPE% --target CYCommon_static

if /i "%LIB_TYPE%"=="Shared" (
    cmake --build "%BUILD_DIR%" --parallel --config %BUILD_TYPE% --target CYCommon_shared
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Build failed.
    exit /b 1
)

echo.
echo ========================================
echo Build completed successfully!
echo Output: %SOURCE_DIR%\Bin\Windows\%TARGET_ARCH%\%CRT_TYPE%\%BUILD_TYPE%
echo ========================================
