@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
set ROOT=%~dp0

echo.
echo ============================================
echo   TRAVELBOX PERU - FIX AND DEPLOY
echo ============================================
echo.
echo Ruta del proyecto: %ROOT%
echo.

REM ================================================================================
REM FIX FLUTTER SDK CACHE
REM ================================================================================
echo [FASE 0/2] REPARANDO FLUTTER SDK
echo ============================================
echo.

echo [1/8] Limpiando cache de Flutter...
call flutter clean
if errorlevel 1 (
    echo [WARNING] flutter clean - continuando de todas formas
)

echo [2/8] Habilitando web support...
call flutter config --enable-web
if errorlevel 1 (
    echo [WARNING] flutter config - continuando de todas formas
)

echo [3/8] Limpiando pubspec.lock...
if exist "%ROOT%pubspec.lock" (
    del /f "%ROOT%pubspec.lock"
    echo [OK] pubspec.lock eliminado
) else (
    echo [INFO] pubspec.lock no existe
)

echo [4/8] Regenerando Flutter web SDK cache...
call flutter precache --web --no-android --no-ios --no-windows --no-macos --no-linux
if errorlevel 1 (
    echo [WARNING] flutter precache - continuando
)

echo [5/8] Upgrading Flutter SDK...
call flutter upgrade --force
if errorlevel 1 (
    echo [WARNING] flutter upgrade - continuando
)

echo.
echo [OK] Flutter SDK reparado.
echo.

REM ================================================================================
REM FRONTEND - Flutter Web Build con Production Config
REM ================================================================================
echo.
echo [FASE 1/2] COMPILANDO FRONTEND FLUTTER WEB
echo ============================================
echo.

echo [6/8] Obteniendo dependencias Flutter...
cd /d "%ROOT%"
call flutter pub get
if errorlevel 1 (
    echo [ERROR] Fallo flutter pub get
    echo Intenta ejecutar manualmente: flutter pub get
    pause
    exit /b 1
)
echo [OK] Dependencias obtenidas.
echo.

echo [7/8] Compilando Flutter Web en modo Release (Produccion)...
call flutter build web --release --web-renderer html
if errorlevel 1 (
    echo [ERROR] Fallo flutter build web
    echo Revisar mensajes de error arriba
    pause
    exit /b 1
)
echo [OK] Frontend compilado exitosamente.
echo.

REM ================================================================================
REM INICIA SERVIDOR WEB EN TERMINAL SEPARADA
REM ================================================================================
echo [8/8] Iniciando servidor web en puerto 8080...
cd /d "%ROOT%build\web"

set PORT=8080
echo [INFO] Usando puerto %PORT%
echo [INFO] URL: http://localhost:%PORT%
echo.

REM Iniciar servidor Python en ventana separada
start "TravelBox Frontend Server" cmd /k python -m http.server %PORT%

timeout /t 3 /nobreak

echo [OK] Servidor web iniciado en nueva ventana.
echo.

REM ================================================================================
REM BACKEND - Spring Boot con Production Config
REM ================================================================================
echo.
echo [FASE 2/2] COMPILANDO BACKEND SPRING BOOT
echo ============================================
echo.

if not exist "%ROOT%..\TravelBox_Peru_Backend" (
    echo [ERROR] No se encontro el backend en: %ROOT%..\TravelBox_Peru_Backend
    echo [INFO] El backend debe estar ubicado en hermano de este directorio
    pause
    exit /b 1
)

echo [INFO] Compilando backend con profile production...
cd /d "%ROOT%..\TravelBox_Peru_Backend"

echo [INFO] Limpiando build anterior del backend...
call mvnw clean -q -DskipTests

echo [INFO] Compilando y empaquetando con Maven (profile: production)...
call mvnw package -DskipTests -Pproduction
if errorlevel 1 (
    echo [ERROR] Fallo la compilacion del backend
    echo Revisar mensajes de error arriba
    pause
    exit /b 1
)

echo [OK] Backend compilado exitosamente.
echo.

echo [INFO] Iniciando backend Spring Boot en nueva ventana...
start "TravelBox Backend Server" cmd /k mvnw spring-boot:run -DskipTests -Pproduction

timeout /t 3 /nobreak

echo.
echo ============================================
echo   DEPLOY COMPLETADO CON EXITO!
echo ============================================
echo.
echo [FRONTEND] URL: http://localhost:8080
echo [BACKEND]  Iniciandose en nueva ventana...
echo.
echo Verifica que ambas ventanas esten ejecutandose correctamente.
echo Presiona una tecla para cerrar esta ventana...
pause
