@echo off
setlocal EnableExtensions EnableDelayedExpansion
title FunSquare Database Setup

cd /d "%~dp0"
set "LOG=%TEMP%\FunSquare-database-setup.log"
set "MYSQL_EXE="
set "BACKUP_FILE="

echo.
echo  =========================================
echo       FunSquare - Safe database setup
echo  =========================================
echo.
echo This script will:
echo   1. Find the local MySQL client
echo   2. Check whether the "es" database already exists
echo   3. Stop if "es" already exists
echo   4. Create "es" and import the newest included backup
echo.
echo No database will be overwritten.
echo.

>>"%LOG%" echo.
>>"%LOG%" echo [%date% %time%] FunSquare database setup started

for /f "delims=" %%P in ('where mysql.exe 2^>nul') do if not defined MYSQL_EXE set "MYSQL_EXE=%%P"
for %%P in (
    "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
    "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
    "C:\Program Files\MariaDB 11.0\bin\mysql.exe"
    "C:\Program Files\MariaDB 10.11\bin\mysql.exe"
) do if not defined MYSQL_EXE if exist "%%~P" set "MYSQL_EXE=%%~P"

if not defined MYSQL_EXE (
    echo [ERROR] mysql.exe was not found.
    echo Install MySQL Server and run this file again.
    start "" "https://dev.mysql.com/downloads/installer/"
    >>"%LOG%" echo [ERROR] mysql.exe was not found
    goto :done
)
echo [OK] MySQL client: !MYSQL_EXE!

for /f "delims=" %%F in ('dir /b /a-d /o:n "backup\*.sql" 2^>nul') do set "BACKUP_FILE=%%F"
if not defined BACKUP_FILE (
    echo [ERROR] No SQL backup was found in the backup folder.
    >>"%LOG%" echo [ERROR] No SQL backup was found
    goto :done
)
set "BACKUP_PATH=%CD%\backup\!BACKUP_FILE!"
echo [OK] Backup selected: !BACKUP_FILE!

sc query MySQL80 >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=4" %%A in ('sc query MySQL80 ^| findstr /i "STATE"') do set "MYSQL_STATE=%%A"
    if /i "!MYSQL_STATE!"=="STOPPED" (
        echo [SETUP] Starting MySQL80...
        net start MySQL80 >>"%LOG%" 2>&1
    )
)

echo.
echo Enter the MySQL root password when prompted.
echo The password is not saved by this script.
echo.

set "DB_CHECK=%TEMP%\funsquare-db-check.txt"
"!MYSQL_EXE!" -u root -p -N -B -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='es';" >"!DB_CHECK!" 2>>"%LOG%"
if errorlevel 1 (
    echo [ERROR] Could not connect to MySQL as root.
    echo Check the password and confirm that MySQL is running.
    >>"%LOG%" echo [ERROR] MySQL root connection failed
    del /q "!DB_CHECK!" >nul 2>&1
    goto :done
)

findstr /x /c:"es" "!DB_CHECK!" >nul 2>&1
if not errorlevel 1 (
    echo [STOPPED] The "es" database already exists.
    echo No import was performed, so existing data was protected.
    echo Use HeidiSQL to inspect or repair the existing database.
    >>"%LOG%" echo [STOPPED] Database es already exists; no import performed
    del /q "!DB_CHECK!" >nul 2>&1
    goto :done
)
del /q "!DB_CHECK!" >nul 2>&1

echo [SETUP] Creating database "es"...
"!MYSQL_EXE!" -u root -p -e "CREATE DATABASE es CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] Could not create database "es".
    >>"%LOG%" echo [ERROR] Could not create database es
    goto :done
)

echo [SETUP] Importing !BACKUP_FILE!...
echo This may take a few minutes.
"!MYSQL_EXE!" -u root -p es <"!BACKUP_PATH!" >>"%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] Database import failed.
    echo Review:
    echo   %LOG%
    >>"%LOG%" echo [ERROR] Database import failed
    goto :done
)

echo.
echo [OK] FunSquare database setup completed.
echo Run run-funsquare.bat to start the application.
>>"%LOG%" echo [OK] FunSquare database setup completed

:done
echo.
echo Setup log:
echo   %LOG%
echo.
pause
endlocal