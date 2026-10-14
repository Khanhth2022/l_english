@echo off
title Dong goi APK LEnglish de test
echo ========================================================
echo   DONG GOI FILE APK LENGLISH (Debug / Test Release)
echo ========================================================
echo.

set NO_PROXY=localhost,127.0.0.1

echo Dang kiem tra moi truong Android SDK...
call flutter doctor

echo.
echo Dang tien hanh dong goi APK...
call flutter build apk --debug

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo   BUILD APK THANH CONG!
    echo   File APK duoc luu tai:
    echo   build\app\outputs\flutter-apk\app-debug.apk
    echo ========================================================
    explorer build\app\outputs\flutter-apk
) else (
    echo.
    echo ========================================================
    echo   Loi build APK: Chua tim thay Android SDK.
    echo   Vui long cai dat Android Studio hoac chay lenh:
    echo   flutter config --android-sdk "<duong-dan-Android-SDK>"
    echo ========================================================
)

pause
