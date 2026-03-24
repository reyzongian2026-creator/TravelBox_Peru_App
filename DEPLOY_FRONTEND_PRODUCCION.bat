@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
set ROOT=%~dp0

echo.
echo ================================================
echo   TRAVELBOX - DEPLOY FRONTEND LOCAL PRODUCCION
echo ================================================
echo.

echo [1/4] Limpiando build anterior...
if exist "%ROOT%build\web" (
    rmdir /s /q "%ROOT%build\web"
)
echo [OK] Build limpiado.
echo.

echo [2/4] Obteniendo dependencias Flutter...
cd /d "%ROOT%"
call flutter pub get
if errorlevel 1 (
    echo [ERROR] Fallo flutter pub get
    pause
    exit /b 1
)
echo [OK] Dependencias obtenidas.
echo.

echo [3/4] Compilando Flutter Web en Release (Produccion)...
call flutter build web --release
if errorlevel 1 (
    echo [ERROR] Fallo la compilacion
    pause
    exit /b 1
)
echo [OK] Compilacion exitosa.
echo.

echo [4/4] Iniciando servidor web en puerto 8080...
cd /d "%ROOT%build\web"
echo.
echo ================================================
echo   FRONTEND LISTO EN: http://localhost:8080
echo ================================================
echo.
python -m http.server 8080
