@echo off
cd /d C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App

echo ================================================
echo Building TravelBox Flutter Web with Firebase
echo ================================================

set FIREBASE_API_KEY=AIzaSyB5pNZ6SEZjd_1UeUIQtfP4ewoGUZEX7k0
set FIREBASE_PROJECT_ID=travelboxperu-f96ee
set FIREBASE_WEB_APP_ID=1:551019035202:web:b87e41122e2b79004b8bdb
set FIREBASE_MESSAGING_SENDER_ID=551019035202
set FIREBASE_AUTH_DOMAIN=travelboxperu-f96ee.firebaseapp.com
set FIREBASE_STORAGE_BUCKET=travelboxperu-f96ee.firebasestorage.app
set FIREBASE_GOOGLE_SERVER_CLIENT_ID=551019035202-3khgoibrmpf8qpets7up6rnond00a83e.apps.googleusercontent.com
set API_BASE_URL=http://localhost:8080/api/v1

flutter build web --release ^
  --dart-define=FIREBASE_API_KEY=%FIREBASE_API_KEY% ^
  --dart-define=FIREBASE_PROJECT_ID=%FIREBASE_PROJECT_ID% ^
  --dart-define=FIREBASE_WEB_APP_ID=%FIREBASE_WEB_APP_ID% ^
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=%FIREBASE_MESSAGING_SENDER_ID% ^
  --dart-define=FIREBASE_AUTH_DOMAIN=%FIREBASE_AUTH_DOMAIN% ^
  --dart-define=FIREBASE_STORAGE_BUCKET=%FIREBASE_STORAGE_BUCKET% ^
  --dart-define=FIREBASE_GOOGLE_SERVER_CLIENT_ID=%FIREBASE_GOOGLE_SERVER_CLIENT_ID% ^
  --dart-define=API_BASE_URL=%API_BASE_URL%

echo.
echo ================================================
echo Build complete!
echo ================================================
pause
