@echo off
title Khoi chay Gia Lap va App LEnglish
echo ========================================================
echo   KHOI CHAY MAY AO ANDROID VA APP LENGLISH
echo ========================================================
echo.

set ADB="%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set EMULATOR="%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe"
set APK="build\app\outputs\flutter-apk\app-debug.apk"

echo 1. Dang mo cua so may ao Pixel 6a...
start "" %EMULATOR% -avd Pixel_6a

echo 2. Dang cho may ao khoi dong xong (boot completed)...
%ADB% wait-for-device
:wait_boot
for /f "tokens=*" %%a in ('%ADB% shell getprop sys.boot_completed 2^>nul') do set BOOT=%%a
if "%BOOT%"=="1" goto boot_done
timeout /t 2 /nobreak >nul
goto wait_boot

:boot_done
echo.
echo 3. Cai dat file APK vao may ao...
%ADB% install -r %APK%

echo.
echo 4. Mo app LEnglish...
%ADB% shell am start -n com.lenglish.l_english/.MainActivity

echo.
echo ========================================================
echo   HOAN TAT! App da duoc mo tren may ao.
echo ========================================================
echo.
pause
