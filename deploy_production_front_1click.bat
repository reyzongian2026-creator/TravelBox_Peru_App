@echo off
setlocal
set ROOT=%~dp0
set DEFAULT_ARGS=-ProjectId travelboxperudb -Region us-central1 -BackendServiceName travelbox-backend-prod -FrontendServiceName travelbox-frontend-prod -BackendVpcConnector travelbox-run-connector -BackendVpcEgress all-traffic -BackendTimeoutSeconds 600 -SkipBackendCompile -SkipBackendDeploy

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%tools\deploy_production_one_click.ps1" %DEFAULT_ARGS% %*
set EXIT_CODE=%ERRORLEVEL%

if not "%EXIT_CODE%"=="0" (
  echo.
  echo [ERROR] El deploy SOLO FRONT fallo. Revisa la salida.
  pause
  exit /b %EXIT_CODE%
)

echo.
echo [OK] Deploy SOLO FRONT completado.
pause
