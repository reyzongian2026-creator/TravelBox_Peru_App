@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
set ROOT=%~dp0

cls
echo.
echo ====================================================
echo   RECOMPILACION COMPLETA DESDE CERO
echo ====================================================
echo.

cd /d "%ROOT%"

echo [1/6] Limpiando completamente...
if exist "build" rmdir /s /q "build"
if exist ".dart_tool" rmdir /s /q ".dart_tool"
if exist "pubspec.lock" del "pubspec.lock"
echo [OK] Limpieza completa.
echo.

echo [2/6] Obteniendo dependencias...
call flutter pub get
if errorlevel 1 (
    echo [ERROR] flutter pub get fallo
    echo Intenta ejecutar manualmente: flutter pub get
    pause
    exit /b 1
)
echo [OK] Dependencias obtenidas.
echo.

echo [3/6] Limpiando cache de Flutter...
call flutter clean
echo [OK] Cache limpiado.
echo.

echo [4/6] Compilando Flutter Web Release (esto tomara tiempo)...
call flutter build web --release --verbose
if errorlevel 1 (
    echo.
    echo [ERROR] La compilacion fallo. Ver mensajes arriba.
    pause
    exit /b 1
)
echo [OK] Compilacion completada.
echo.

echo [5/6] Verificando archivos generados...
echo.
echo Archivos en build\web:
dir /B "%ROOT%build\web"
echo.

if not exist "%ROOT%build\web\index.html" (
    echo [ERROR CRITICO] index.html NO se genero
    echo Los archivos generados:
    dir /s "%ROOT%build\web"
    echo.
    echo Posible problema:
    echo - Flutter no esta correctamente instalado
    echo - Falta una dependencia
    echo - Problema con el pubspec.yaml
    echo.
    pause
    exit /b 1
)
echo [OK] index.html encontrado
echo.

echo [6/6] Iniciando servidor...
cd /d "%ROOT%build\web"

REM Iniciar servidor en ventana separada
start "TravelBox Server" cmd /k python -m http.server 8080

timeout /t 2 /nobreak

REM Abrir navegador
echo Abriendo http://localhost:8080...
start http://localhost:8080

echo.
echo ====================================================
echo [OK] LISTO EN http://localhost:8080
echo ====================================================
echo.
pause
