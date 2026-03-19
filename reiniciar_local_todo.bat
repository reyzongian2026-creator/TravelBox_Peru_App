@echo off
setlocal
set ROOT=%~dp0

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%tools\local_reset_bootstrap.ps1"
set EXIT_CODE=%ERRORLEVEL%

if not "%EXIT_CODE%"=="0" (
  echo.
  echo [ERROR] El reinicio local fallo. Revisa el log de consola.
  pause
  exit /b %EXIT_CODE%
)

echo.
echo [OK] Reinicio local completado.
pause
