@echo off
title Chay LEnglish tren Android Emulator (Backend may ao 10.0.2.2:8080)
set BACKEND_URL=http://10.0.2.2:8080
if not "%~1"=="" set BACKEND_URL=%~1
echo Dang khoi chay LEnglish tren May ao Android voi Backend:
echo %BACKEND_URL%
echo.
set NO_PROXY=localhost,127.0.0.1,10.0.2.2
flutter run -d android --no-pub --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=%BACKEND_URL%
pause
