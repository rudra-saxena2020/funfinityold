@echo off
setlocal EnableExtensions EnableDelayedExpansion
title FunSquare UDP Setup and Launcher

rem Run from this file's folder so the EXE can find its DLLs and data.
cd /d "%~dp0"

set "APP=FunSquare-UDP.exe"
set "DISCOVERY=FunSquareNetworkDiscovery.exe"
set "LOG=%TEMP%\FunSquare-UDP-launcher.log"
set "SETUP_DIR=%TEMP%\FunSquare-Setup"
set "DOTNET_EXE=%SETUP_DIR%\ndp48-x86-x64-allos-enu.exe"
set "DOTNET_URL=https://go.microsoft.com/fwlink/?linkid=2088631"
set "MYSQL_URL=https://dev.mysql.com/downloads/installer/"
set "RUN_BAT=%~f0"
set "APP_DIR=%~dp0"

echo.
echo  ================================================
echo     FunSquare UDP - Setup and automatic launcher
echo  ================================================
echo.
echo Release folder:
echo   %CD%
echo.

>>"%LOG%" echo.
>>"%LOG%" echo [%date% %time%] FunSquare setup and launcher started
>>"%LOG%" echo Release folder: %CD%

call :check_release_files
if errorlevel 1 goto :failed

call :ensure_dotnet
if errorlevel 1 goto :missing_dotnet

call :ensure_mysql
if errorlevel 1 goto :missing_mysql

call :create_desktop_shortcut

if exist "%DISCOVERY%" (
    tasklist /FI "IMAGENAME eq %DISCOVERY%" 2>nul | find /I "%DISCOVERY%" >nul
    if errorlevel 1 (
        echo [OK] Starting network discovery...
        >>"%LOG%" echo Starting %DISCOVERY%
        start "FunSquare Network Discovery" /min "%APP_DIR%%DISCOVERY%"
    ) else (
        echo [OK] Network discovery is already running.
        >>"%LOG%" echo Network discovery already running
    )
)

echo.
echo [OK] Starting %APP%...
echo If the app closes, review:
echo   %LOG%
echo.
>>"%LOG%" echo Starting %APP%

start "FunSquare UDP" /wait "%APP_DIR%%APP%"
set "APP_EXIT=!ERRORLEVEL!"

>>"%LOG%" echo [%date% %time%] %APP% exited with code !APP_EXIT!
echo.
echo FunSquare UDP closed with exit code !APP_EXIT!.
echo Diagnostic log:
echo   %LOG%
goto :done

:check_release_files
set "MISSING=0"
echo [SETUP] Checking release files...

for %%F in ("%APP%" "%DISCOVERY%" "MySql.Data.dll" "Newtonsoft.Json.dll" "EmbedIO.dll") do (
    if not exist "%%~F" (
        echo [ERROR] Missing file: %%~F
        >>"%LOG%" echo [ERROR] Missing file: %%~F
        set "MISSING=1"
    )
)

for %%D in ("setting" "resource" "df") do (
    if not exist "%%~D\" (
        echo [ERROR] Missing folder: %%~D
        >>"%LOG%" echo [ERROR] Missing folder: %%~D
        set "MISSING=1"
    )
)

if "!MISSING!"=="1" exit /b 1
echo [OK] Required application files are present.
>>"%LOG%" echo Required application files are present
exit /b 0

:ensure_dotnet
call :read_dotnet_release
if defined DOTNET_RELEASE (
    set /a DOTNET_RELEASE_NUMBER=!DOTNET_RELEASE! >nul 2>&1
    if !DOTNET_RELEASE_NUMBER! GEQ 528040 (
        echo [OK] .NET Framework 4.8 is installed.
        >>"%LOG%" echo .NET Framework 4.8 is installed. Release: !DOTNET_RELEASE!
        exit /b 0
    )
    echo [SETUP] An older .NET Framework release was found: !DOTNET_RELEASE!
) else (
    echo [SETUP] .NET Framework 4.8 was not detected.
)

if not exist "%SETUP_DIR%\" mkdir "%SETUP_DIR%" >nul 2>&1
echo [SETUP] Downloading the official .NET Framework 4.8 installer...
echo This may open a Windows permission prompt.
>>"%LOG%" echo Downloading .NET Framework 4.8 from Microsoft

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%DOTNET_URL%' -OutFile $env:DOTNET_EXE" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] .NET Framework download failed.
    >>"%LOG%" echo [ERROR] .NET Framework download failed
    exit /b 1
)
if not exist "%DOTNET_EXE%" (
    echo [ERROR] .NET Framework installer was not downloaded.
    >>"%LOG%" echo [ERROR] .NET Framework installer was not downloaded
    exit /b 1
)

echo [SETUP] Installing .NET Framework 4.8...
>>"%LOG%" echo Starting .NET Framework installer
powershell -NoProfile -Command "Start-Process -FilePath $env:DOTNET_EXE -ArgumentList '/quiet','/norestart' -Verb RunAs -Wait" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] .NET Framework installation was cancelled or failed.
    >>"%LOG%" echo [ERROR] .NET Framework installation was cancelled or failed
    exit /b 1
)

call :read_dotnet_release
if defined DOTNET_RELEASE (
    set /a DOTNET_RELEASE_NUMBER=!DOTNET_RELEASE! >nul 2>&1
    if !DOTNET_RELEASE_NUMBER! GEQ 528040 (
        echo [OK] .NET Framework 4.8 installation completed.
        >>"%LOG%" echo .NET Framework 4.8 installation completed
        exit /b 0
    )
)
echo [ERROR] .NET Framework 4.8 is still not available. A restart may be required.
>>"%LOG%" echo [ERROR] .NET Framework 4.8 is still not available
exit /b 1

:read_dotnet_release
set "DOTNET_RELEASE="
for %%V in (64 32) do (
    for /f "tokens=1,2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release /reg:%%V 2^>nul ^| findstr /i "Release"') do (
        if /i "%%A"=="Release" set "DOTNET_RELEASE=%%C"
    )
)
exit /b 0

:ensure_mysql
set "MYSQL_OK=0"
for %%S in (MySQL80 MySQL MariaDB) do (
    if "!MYSQL_OK!"=="0" (
        call :start_mysql_service %%S
        if not errorlevel 1 (
            set "MYSQL_OK=1"
            set "MYSQL_SERVICE=%%S"
        )
    )
)

if "!MYSQL_OK!"=="1" (
    echo [OK] Database service !MYSQL_SERVICE! is available.
    >>"%LOG%" echo Database service !MYSQL_SERVICE! is available
    exit /b 0
)

echo [ERROR] No MySQL or MariaDB Windows service was found.
echo FunSquare needs its configured database before it can open.
echo The official MySQL installer page can be opened from the next prompt.
>>"%LOG%" echo [ERROR] No MySQL or MariaDB Windows service was found
exit /b 1

:start_mysql_service
set "SERVICE=%~1"
set "SERVICE_STATE="
sc query "%SERVICE%" >nul 2>&1
if errorlevel 1 exit /b 1

for /f "tokens=4" %%A in ('sc query "%SERVICE%" ^| findstr /i "STATE"') do set "SERVICE_STATE=%%A"
if /i "!SERVICE_STATE!"=="RUNNING" exit /b 0

echo [SETUP] Starting database service %SERVICE%...
>>"%LOG%" echo Attempting to start database service %SERVICE%
net start "%SERVICE%" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [WARNING] Could not start %SERVICE%. Administrator permission may be required.
    exit /b 1
)
exit /b 0

:create_desktop_shortcut
powershell -NoProfile -Command "$w=New-Object -ComObject WScript.Shell; $s=$w.CreateShortcut([Environment]::GetFolderPath('Desktop')+'\FunSquare UDP.lnk'); $s.TargetPath=$env:RUN_BAT; $s.WorkingDirectory=$env:APP_DIR; $s.IconLocation=$env:APP_DIR+'FunSquare-UDP.exe,0'; $s.Save()" >>"%LOG%" 2>&1
if not errorlevel 1 echo [OK] Desktop shortcut created or updated.
exit /b 0

:failed
echo.
echo [ERROR] Required release files are missing.
echo Re-extract the complete release-v82 folder and run this BAT again.
echo Diagnostic log:
echo   %LOG%
goto :done

:missing_dotnet
echo.
echo FunSquare UDP was not started because .NET Framework 4.8 setup failed.
echo Install it manually from:
echo   https://dotnet.microsoft.com/download/dotnet-framework/net48
echo Then restart Windows if requested and run this BAT again.
echo Diagnostic log:
echo   %LOG%
goto :done

:missing_mysql
echo.
echo FunSquare UDP was not started because no MySQL/MariaDB service is available.
choice /C YN /N /M "Open the official MySQL installer page now? [Y/N] "
if errorlevel 2 goto :done
start "" "%MYSQL_URL%"
echo.
echo Install and configure MySQL, then run this BAT again.
echo Diagnostic log:
echo   %LOG%

:done
echo.
pause
endlocal