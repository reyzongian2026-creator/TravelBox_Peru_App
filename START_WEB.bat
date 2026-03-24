@echo off
cd /d C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App\build\web
title TravelBox Frontend - Puerto 5173
echo ================================================
echo STARTING TRAVELBOX FRONTEND
echo Puerto: 5173
echo URL: http://localhost:5173
echo ================================================
start http://localhost:5173
python -m http.server 5173
pause
