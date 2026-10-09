@echo off
title Chay LEnglish tren Chrome (Tat CORS Dev Mode)
echo Dang khoi chay LEnglish tren Google Chrome (Disable CORS Web Security)
echo Backend URL: https://flooring-partners-surely-developer.trycloudflare.com
echo.
set NO_PROXY=localhost,127.0.0.1
flutter run -d chrome --no-pub --web-browser-flag="--disable-web-security" --web-browser-flag="--user-data-dir=%TEMP%\chrome_dev_user" --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://flooring-partners-surely-developer.trycloudflare.com
pause
