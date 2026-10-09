@echo off
title Chay LEnglish tren Android Emulator (Backend Cloudflare)
set BACKEND_URL=https://neighborhood-compliance-gratis-sensors.trycloudflare.com
if not "%~1"=="" set BACKEND_URL=%~1
echo Dang khoi chay LEnglish tren May ao Android voi Backend:
echo %BACKEND_URL%
echo.
set NO_PROXY=localhost,127.0.0.1
flutter run -d android --no-pub --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=%BACKEND_URL%
pause
