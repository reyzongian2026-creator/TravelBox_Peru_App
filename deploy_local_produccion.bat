@echo off
setlocal
set ROOT=%~dp0

echo ============================================
echo   TRAVELBOX PERU - DEPLOY LOCAL PRODUCCION
echo ============================================
echo.

REM ================================================================================
REM FRONTEND - Flutter Web Build con Production Config
REM ================================================================================
echo [1/4] Limpiando build anterior...
cd /d "%ROOT%"
if exist "build\web" rmdir /s /q "build\web"

echo [2/4] Obteniendo dependencias Flutter...
call flutter pub get
if errorlevel 1 (
    echo [ERROR] Fallo flutter pub get
    pause
    exit /b 1
)

echo [3/4] Compilando Flutter Web (Production)...
call flutter build web --release
if errorlevel 1 (
    echo [ERROR] Fallo flutter build web
    pause
    exit /b 1
)

echo [4/4] Iniciando servidor web...
cd /d "%ROOT%build\web"
start /b python -m http.server 8080

echo.
echo ============================================
echo   FRONTEND LISTO
echo   URL: http://localhost:8080
echo ============================================
echo.

REM ================================================================================
REM BACKEND - Spring Boot con Production Config
REM ================================================================================
echo [BACKEND] Compilando y iniciando backend...
cd /d "%ROOT%..\TravelBox_Peru_Backend"

echo [BACKEND] Limpiando build anterior...
call mvnw clean -q

echo [BACKEND] Compilando con profile production...
call mvnw package -DskipTests -Pproduction

echo [BACKEND] Iniciando aplicacion...
call mvnw spring-boot:run -DskipTests -Pproduction

echo.
echo [OK] Deploy de produccion completado!
pause