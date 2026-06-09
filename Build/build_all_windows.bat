@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM CYCommon Windows Matrix Build Script
REM Builds all combinations of arch / lib-type / build-type / CRT
REM ============================================================

set "SCRIPT_DIR=%~dp0"

set "ARCHES=%~1"
set "LIB_TYPES=%~2"
set "BUILD_TYPES=%~3"
set "CRT_TYPES=%~4"

REM ---------- Defaults ----------
if "%ARCHES%"=="" set "ARCHES=x86_64,x86"
if "%LIB_TYPES%"=="" set "LIB_TYPES=Static"
if "%BUILD_TYPES%"=="" set "BUILD_TYPES=Release,Debug"
if "%CRT_TYPES%"=="" set "CRT_TYPES=MD,MT"

echo ========================================
echo CYCommon Windows Matrix Build
echo ========================================
echo   Architectures : %ARCHES%
echo   Library Types : %LIB_TYPES%
echo   Build Types   : %BUILD_TYPES%
echo   CRT Types     : %CRT_TYPES%
echo ========================================

REM ---------- Build all combinations ----------
for %%a in (%ARCHES%) do (
    for %%l in (%LIB_TYPES%) do (
        for %%b in (%BUILD_TYPES%) do (
            for %%c in (%CRT_TYPES%) do (
                echo.
                echo ========================================
                echo Building: arch=%%a lib=%%l type=%%b crt=%%c
                echo ========================================

                call "%SCRIPT_DIR%build_windows.bat" %%b %%l %%a %%c

                if %ERRORLEVEL% NEQ 0 (
                    echo.
                    echo ERROR: Build failed for arch=%%a lib=%%l type=%%b crt=%%c
                    exit /b 1
                )
            )
        )
    )
)

echo.
echo ========================================
echo All Windows matrix builds completed!
echo ========================================
