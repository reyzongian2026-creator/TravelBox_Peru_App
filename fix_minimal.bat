@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
set ROOT=%~dp0

REM Crear archivo de log con timestamp
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)
set LOGFILE=%ROOT%logs\fix_minimal_%mydate%_%mytime%.log
if not exist "%ROOT%logs" mkdir "%ROOT%logs"

echo. >> "%LOGFILE%"
echo ============================================ >> "%LOGFILE%"
echo   TRAVELBOX PERU - MINIMAL FIX >> "%LOGFILE%"
echo   START TIME: %mydate% %mytime% >> "%LOGFILE%"
echo ============================================ >> "%LOGFILE%"
echo. >> "%LOGFILE%"

echo.
echo ============================================
echo   TRAVELBOX PERU - MINIMAL FIX
echo ============================================
echo.
echo Log file: %LOGFILE%
echo.

REM ================================================================================
REM KILL ALL BLOCKING PROCESSES
REM ================================================================================
echo [FASE 0/1] Deteniendo procesos...
echo.

echo Matando procesos de Flutter...
taskkill /F /IM dart.exe 2>nul
taskkill /F /IM chrome.exe 2>nul
taskkill /F /IM java.exe 2>nul
taskkill /F /IM python.exe 2>nul
taskkill /F /IM node.exe 2>nul

echo. >> "%LOGFILE%"
echo [FASE 0/1] Deteniendo procesos... >> "%LOGFILE%"
wmic process list brief >> "%LOGFILE%" 2>&1

timeout /t 3 /nobreak

REM ================================================================================
REM FIX FLUTTER WEB SDK
REM ================================================================================
echo.
echo [FASE 1/2] Reparando Flutter SDK...
echo.

cd /d "%ROOT%"

echo [1/4] Limpiando cache minimal de Flutter...
call flutter clean >> "%LOGFILE%" 2>&1

echo [2/4] Habilitando soporte web...
call flutter config --enable-web >> "%LOGFILE%" 2>&1

echo [3/4] Regenerando Flutter Web SDK...
call flutter precache --web --force-download >> "%LOGFILE%" 2>&1

echo [4/4] Obteniendo dependencias...
call flutter pub get >> "%LOGFILE%" 2>&1
if errorlevel 1 (
    echo [ERROR] flutter pub get falló >> "%LOGFILE%"
    echo [ERROR] flutter pub get falló
    echo Intenta ejecutar de nuevo manualmente:
    echo   flutter pub upgrade
    echo Ver log en: %LOGFILE%
    pause
    exit /b 1
)

echo. >> "%LOGFILE%"
echo [OK] Flutter SDK reparado! >> "%LOGFILE%"
echo.
echo [OK] Flutter SDK reparado!

REM ================================================================================
REM BUILD
REM ================================================================================
echo.
echo [FASE 2/2] Compilando...
echo.

call flutter build web --release --web-renderer html
if errorlevel 1 (
    echo [ERROR] Compilacion falló
    pause
    exit /b 1
)

echo.
echo ============================================
echo   COMPILACION COMPLETADA!
echo ============================================
echo.
echo [SIGUIENTE PASO] Inicia servidor web:
echo   cd %ROOT%build\web
echo   python -m http.server 8080
echo.
echo Luego abre: http://localhost:8080
echo.
pause
