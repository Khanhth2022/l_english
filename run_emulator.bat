@echo off
title Chay LEnglish tren Android Emulator (Backend Cloudflare)
echo Dang khoi chay LEnglish tren May ao Android voi Backend:
echo https://flooring-partners-surely-developer.trycloudflare.com
echo.
set NO_PROXY=localhost,127.0.0.1
flutter run -d android --no-pub --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://flooring-partners-surely-developer.trycloudflare.com
pause
