@echo off
setlocal
set ROOT=%~dp0

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%tools\deploy_production_env_only.ps1" %*
set EXIT_CODE=%ERRORLEVEL%

if not "%EXIT_CODE%"=="0" (
  echo.
  echo [ERROR] El deploy de produccion (ENV-only) fallo. Revisa la salida.
  pause
  exit /b %EXIT_CODE%
)

echo.
echo [OK] Deploy de produccion (ENV-only) completado.
pause
