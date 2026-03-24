@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
set ROOT=%~dp0

echo.
echo ====================================================
echo   TRAVELBOX - DEPLOY FRONTEND CON AUTO NAVEGADOR
echo ====================================================
echo.

REM Limpiar build anterior
echo [1/5] Limpiando...
cd /d "%ROOT%"
if exist "build\web" rmdir /s /q "build\web"

REM Obtener dependencias
echo [2/5] Obteniendo dependencias Flutter...
call flutter pub get
if errorlevel 1 (
    echo [ERROR] flutter pub get fallo
    pause
    exit /b 1
)

REM Compilar
echo [3/5] Compilando Flutter Web Release...
call flutter build web --release
if errorlevel 1 (
    echo [ERROR] flutter build web fallo
    pause
    exit /b 1
)

REM Verificar
echo [4/5] Verificando build...
if not exist "%ROOT%build\web\index.html" (
    echo [ERROR] index.html no existe en build\web
    echo Archivos generados:
    dir "%ROOT%build\web"
    pause
    exit /b 1
)

echo [OK] Build completo y verificado.
echo.

REM Iniciar servidor y navegador
echo [5/5] Iniciando servidor en puerto 8080...
cd /d "%ROOT%build\web"

REM Iniciar servidor Python en ventana separada
start "TravelBox Frontend" cmd /k python -m http.server 8080

REM Esperar a que el servidor esté listo
timeout /t 3 /nobreak

REM Abrir navegador
echo.
echo Abriendo navegador en http://localhost:8080...
start http://localhost:8080

echo.
echo ====================================================
echo  SERVIDOR CORRIENDO EN http://localhost:8080
echo  El navegador se abrira en segundos...
echo ====================================================
echo.
pause
