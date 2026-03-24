@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set ROOT=%~dp0

echo.
echo ============================================
echo   DIAGNOSTICO DE BUILD FRONTEND
echo ============================================
echo.

echo [INFO] Directorio raiz: %ROOT%
echo.

echo [PASO 1] Verificando si existe build\web...
if exist "%ROOT%build\web" (
    echo [OK] Directorio build\web existe
    dir "%ROOT%build\web"
) else (
    echo [ERROR] No existe build\web
)
echo.

echo [PASO 2] Verificando index.html...
if exist "%ROOT%build\web\index.html" (
    echo [OK] index.html existe
    echo Primeras lineas:
    type "%ROOT%build\web\index.html" | findstr /n "^" | findstr /B /C:"1:" /C:"2:" /C:"3:" /C:"4:" /C:"5:"
) else (
    echo [ERROR] index.html no existe
)
echo.

echo [PASO 3] Verificando estructura de archivos...
cd /d "%ROOT%build\web"
echo Archivos en build\web:
dir /B

echo.
echo [PASO 4] Limpiando build anterior y recompilando...
cd /d "%ROOT%"
echo Eliminando build\web...
if exist "build\web" rmdir /s /q "build\web"
echo.

echo Obteniendo dependencias...
call flutter pub get

echo.
echo Compilando web release...
call flutter build web --release

echo.
echo [PASO 5] Verificando nuevo build...
if exist "%ROOT%build\web\index.html" (
    echo [OK] index.html creado exitosamente
) else (
    echo [ERROR] index.html NO se creo
)

echo.
echo Presiona una tecla para continuar...
pause
