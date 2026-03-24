@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
set ROOT=%~dp0

echo.
echo ============================================
echo   TRAVELBOX PERU - DEEP FIX AND DEPLOY
echo ============================================
echo.
echo IMPORTANTE: Este script realiza limpieza completa
echo Ruta del proyecto: %ROOT%
echo.

REM ================================================================================
REM PHASE 1: DEEP CLEAN
REM ================================================================================
echo [FASE 0/3] LIMPIEZA PROFUNDA
echo ============================================
echo.

echo [1/12] Deteniendo procesos en ejecucion...
REM Mata procesos de Flutter, Chrome, y otros que puedan bloquear archivos
taskkill /F /IM dart.exe 2>nul
taskkill /F /IM chrome.exe 2>nul
taskkill /F /IM java.exe 2>nul
taskkill /F /IM python.exe 2>nul
taskkill /F /IM flutter.bat 2>nul
timeout /t 3 /nobreak

echo [2/12] Limpiando directorios build (con reintentos)...
cd /d "%ROOT%"

REM Intenta eliminar build con reintentos
set RETRY=0
:RETRY_BUILD
if exist "build" (
    rmdir /s /q "build" 2>nul
    if exist "build" (
        set /a RETRY=RETRY+1
        if %RETRY% LSS 3 (
            echo [INFO] Reintentando eliminar build (intento %RETRY%)
            timeout /t 2 /nobreak
            goto RETRY_BUILD
        ) else (
            echo [WARNING] No se pudo eliminar build completamente - continuando
        )
    )
)

REM Limpia otros directorios
if exist ".dart_tool" (
    rmdir /s /q ".dart_tool" 2>nul
)
if exist "pubspec.lock" (
    del /f /q "pubspec.lock" 2>nul
)

echo [OK] Directorios limpiados.
echo.

echo [3/12] Ejecutando flutter clean...
call flutter clean
timeout /t 2 /nobreak
echo.

echo [4/12] Habilitando soporte web...
call flutter config --enable-web
echo.

echo [5/12] Actualizando Flutter SDK...
call flutter upgrade
timeout /t 3 /nobreak
echo.

echo [6/12] Regenerando Flutter web SDK cache (paso 1)...
call flutter precache --web
timeout /t 2 /nobreak
echo.

echo [7/12] Regenerando Flutter web SDK cache (paso 2)...
call flutter precache --force-download --web
timeout /t 2 /nobreak
echo.

echo [OK] Limpieza profunda completada.
echo.

REM ================================================================================
REM PHASE 2: DEPENDENCY RESOLUTION
REM ================================================================================
echo.
echo [FASE 1/3] RESOLVIENDO DEPENDENCIAS
echo ============================================
echo.

echo [8/12] Obteniendo dependencias de Pub...
cd /d "%ROOT%"
call flutter pub get
if errorlevel 1 (
    echo [WARNING] flutter pub get retornó error, intentando upupgrade...
    call flutter pub upgrade
    if errorlevel 1 (
        echo [ERROR] Fallo flutter pub upgrade
        echo Por favor, verifica los conflictos de dependencias en pubspec.yaml
        pause
        exit /b 1
    )
)
echo [OK] Dependencias resueltas.
echo.

echo [9/12] Verificando dependencias...
call flutter pub outdated --no-dev
echo.

REM ================================================================================
REM PHASE 3: BUILD PRODUCTION
REM ================================================================================
echo.
echo [FASE 2/3] COMPILANDO FRONTEND
echo ============================================
echo.

echo [10/12] Compilando Flutter Web en modo Release...
call flutter build web --release --web-renderer html
if errorlevel 1 (
    echo [ERROR] Fallo flutter build web --release
    echo Intentando con configuracion alternativa...
    call flutter build web --release
    if errorlevel 1 (
        echo [ERROR] Fallo compilacion even con alternativa
        pause
        exit /b 1
    )
)
echo [OK] Frontend compilado.
echo.

REM ================================================================================
REM PHASE 4: START SERVERS
REM ================================================================================
echo.
echo [FASE 3/3] INICIANDO SERVIDORES
echo ============================================
echo.

echo [11/12] Iniciando servidor web en puerto 8080...
cd /d "%ROOT%build\web"
start "TravelBox Frontend Server" cmd /k python -m http.server 8080
timeout /t 3 /nobreak
echo [OK] Frontend en http://localhost:8080
echo.

echo [12/12] Iniciando backend (si existe)...
if exist "%ROOT%..\TravelBox_Peru_Backend" (
    cd /d "%ROOT%..\TravelBox_Peru_Backend"
    call mvnw clean -q -DskipTests 2>nul
    call mvnw package -DskipTests -Pproduction 2>nul
    start "TravelBox Backend Server" cmd /k mvnw spring-boot:run -DskipTests -Pproduction
    echo [OK] Backend iniciandose...
) else (
    echo [INFO] Backend no encontrado - saltando
)

echo.
echo ============================================
echo   DEPLOY COMPLETADO!
echo ============================================
echo.
echo [FRONTEND] http://localhost:8080
echo.
echo Presiona una tecla para cerrar esta ventana...
pause
