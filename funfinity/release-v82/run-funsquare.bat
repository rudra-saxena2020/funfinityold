@echo off
setlocal EnableExtensions
title FunSquare UDP Launcher

rem Always run from this script's folder so the EXE can find its DLLs and data.
cd /d "%~dp0"

set "APP=FunSquare-UDP.exe"
set "DISCOVERY=FunSquareNetworkDiscovery.exe"
set "LOG=%TEMP%\FunSquare-UDP-launcher.log"
set "START_DISCOVERY=1"

echo.
echo  ==========================================
echo        FunSquare UDP - Starting application
echo  ==========================================
echo.
echo Launcher folder:
echo   %CD%
echo.

>>"%LOG%" echo.
>>"%LOG%" echo [%date% %time%] FunSquare launcher started
>>"%LOG%" echo Folder: %CD%

if not exist "%APP%" (
    echo [ERROR] %APP% was not found.
    echo.
    echo Extract the complete release-v82 folder and run this BAT file
    echo from the same folder as %APP%.
    >>"%LOG%" echo [ERROR] %APP% was not found.
    goto :failed
)

rem FunSquare UDP targets .NET Framework 4.8. Check both Windows registry views.
rem The Release value is the third field: Release REG_DWORD 0x80xxxx.
set "DOTNET_RELEASE="
set "DOTNET_VIEW="
set "DOTNET_OK=0"
for %%V in (64 32) do (
    for /f "tokens=1,2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release /reg:%%V 2^>nul ^| findstr /i "Release"') do (
        if /i "%%A"=="Release" (
            set "DOTNET_RELEASE=%%C"
            set "DOTNET_VIEW=%%V-bit registry"
        )
    )
)

if not defined DOTNET_RELEASE (
    echo [WARNING] .NET Framework 4.8 was not detected.
    echo Install .NET Framework 4.8, then run this file again.
    echo Download: https://dotnet.microsoft.com/download/dotnet-framework/net48
    echo.
    >>"%LOG%" echo [WARNING] .NET Framework 4.8 was not detected.
) else (
    set /a DOTNET_RELEASE_NUMBER=!DOTNET_RELEASE! >nul 2>&1
    if !DOTNET_RELEASE_NUMBER! GEQ 528040 (
        echo [OK] .NET Framework 4.8 detected in !DOTNET_VIEW!. Release: !DOTNET_RELEASE!
        >>"%LOG%" echo .NET Framework 4.8 detected in !DOTNET_VIEW!. Release: !DOTNET_RELEASE!
        set "DOTNET_OK=1"
    ) else (
        echo [ERROR] .NET Framework 4.8 is required.
        echo An older .NET Framework release was found: !DOTNET_RELEASE!
        echo Download: https://dotnet.microsoft.com/download/dotnet-framework/net48
        echo.
        >>"%LOG%" echo [ERROR] Older .NET Framework release found: !DOTNET_RELEASE!
    )
)
if not "!DOTNET_OK!"=="1" goto :missing_dotnet

rem The app uses MySQL. Start a standard Windows service only if it already exists.
rem No database is installed or created by this launcher.
call :start_mysql_service MySQL80
if not "%ERRORLEVEL%"=="0" call :start_mysql_service MySQL
if not "%ERRORLEVEL%"=="0" call :start_mysql_service MariaDB

if "%START_DISCOVERY%"=="1" if exist "%DISCOVERY%" (
    echo [OK] Starting network discovery...
    >>"%LOG%" echo Starting %DISCOVERY%
    start "FunSquare Network Discovery" /min "%~dp0%DISCOVERY%"
)

echo.
echo [OK] Starting %APP%...
echo If the window closes immediately, review:
echo   %LOG%
echo.
>>"%LOG%" echo Starting %APP%

start "FunSquare UDP" /wait "%~dp0%APP%"
set "APP_EXIT=%ERRORLEVEL%"

>>"%LOG%" echo [%date% %time%] %APP% exited with code %APP_EXIT%
echo.
echo FunSquare UDP closed with exit code %APP_EXIT%.
echo Diagnostic log:
echo   %LOG%
goto :done

:start_mysql_service
set "SERVICE=%~1"
sc query "%SERVICE%" >nul 2>&1
if errorlevel 1 exit /b 1

for /f "tokens=4" %%A in ('sc query "%SERVICE%" ^| findstr /i "STATE"') do set "SERVICE_STATE=%%A"
if /i "%SERVICE_STATE%"=="RUNNING" (
    echo [OK] MySQL service %SERVICE% is already running.
    >>"%LOG%" echo MySQL service %SERVICE% already running
    exit /b 0
)

echo [INFO] Found MySQL service %SERVICE%; attempting to start it...
>>"%LOG%" echo Attempting to start MySQL service %SERVICE%
net start "%SERVICE%" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [WARNING] Could not start %SERVICE%. Run this launcher as Administrator
    echo or start the database service manually.
    exit /b 1
)
echo [OK] MySQL service %SERVICE% started.
exit /b 0

:failed
echo.
echo The launcher could not start FunSquare UDP.
echo Diagnostic log:
echo   %LOG%
goto :done

:missing_dotnet
echo.
echo FunSquare UDP was not started because .NET Framework 4.8 is required.
echo Install it, restart Windows if requested, and run this BAT file again.
echo Diagnostic log:
echo   %LOG%
echo.
choice /C YN /N /M "Open the official .NET Framework 4.8 download page now? [Y/N] "
if errorlevel 2 goto :done
start "" "https://dotnet.microsoft.com/download/dotnet-framework/net48"
echo.
echo The official Microsoft download page has been opened in your browser.
echo Install .NET Framework 4.8, then run this launcher again.

:done
echo.
pause
endlocal