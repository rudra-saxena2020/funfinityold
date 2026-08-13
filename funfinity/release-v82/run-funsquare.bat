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

rem FunSquare UDP targets .NET Framework 4.8. Show a warning if it is absent.
set "DOTNET_RELEASE="
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release 2^>nul') do if /i "%%A"=="Release" set "DOTNET_RELEASE=%%B"

if not defined DOTNET_RELEASE (
    echo [WARNING] .NET Framework 4.8 was not detected.
    echo Install .NET Framework 4.8, then run this file again.
    echo.
    >>"%LOG%" echo [WARNING] .NET Framework 4.8 was not detected.
) else (
    echo [OK] .NET Framework detected. Registry release: %DOTNET_RELEASE%
    >>"%LOG%" echo .NET Framework registry release: %DOTNET_RELEASE%
)

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

:done
echo.
pause
endlocal