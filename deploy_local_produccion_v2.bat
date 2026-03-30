@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
set ROOT=%~dp0

echo.
echo ============================================
echo   TRAVELBOX PERU - DEPLOY LOCAL PRODUCCION
echo ============================================
echo.
echo Ruta del proyecto: %ROOT%
echo.

REM ================================================================================
REM FRONTEND - Flutter Web Build con Production Config
REM ================================================================================
echo.
echo [FASE 1/2] COMPILANDO FRONTEND FLUTTER WEB
echo ============================================
echo.

echo [1/5] Limpiando build anterior...
if exist "%ROOT%build\web" (
    echo   Eliminando directorio build\web...
    rmdir /s /q "%ROOT%build\web"
    timeout /t 2 /nobreak
)

echo [OK] Build anterior limpiado.
echo.

echo [2/5] Obteniendo dependencias Flutter...
cd /d "%ROOT%"
call flutter pub get
if errorlevel 1 (
    echo [ERROR] Fallo flutter pub get
    pause
    exit /b 1
)
echo [OK] Dependencias obtenidas.
echo.

echo [3/5] Compilando Flutter Web en modo Release (Produccion)...
call flutter build web --release ^
  --dart-define=USE_MOCK_FALLBACK=false ^
  --dart-define=API_BASE_URL=https://api.inkavoy.pe/api/v1
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
echo [4/5] Iniciando servidor web en puerto 8080...
cd /d "%ROOT%build\web"

REM Obtener puerto disponible
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

echo [5/5] Compilando backend con profile production...
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
