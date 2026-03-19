# Homologacion Front/Back + Despliegue 1 Click

Fecha de validacion tecnica: 2026-03-18 (America/Lima).

## 1) Estado de homologacion

### Seguridad de tokens
- Front usa almacenamiento seguro del sistema operativo (`flutter_secure_storage`) para `accessToken` y `refreshToken`.
- Archivo: `lib/shared/state/session_token_storage.dart`.

### Frontera de errores (AppException)
- Repositorios del front convierten `DioException` a `AppException`.
- Archivos:
  - `lib/shared/utils/app_exception.dart`
  - `lib/features/reservation/data/reservation_repository_impl.dart`

### Rendimiento Riverpod en listas
- Front separa ids y detalle por `provider.family/select` para evitar repintar listas completas.
- Archivos:
  - `lib/features/reservation/presentation/reservation_providers.dart`
  - `lib/features/reservation/presentation/my_reservations_page.dart`

### SSE y ciclo de vida
- Controlador de notificaciones usa `WidgetsBindingObserver` y desconecta/reconecta SSE segun `AppLifecycleState`.
- Archivos:
  - `lib/shared/state/notification_center_controller.dart`
  - `lib/shared/realtime/notification_live_events_io.dart`

### Resiliencia de red
- API client usa `dio_smart_retry` con 3 reintentos (1s, 2s, 3s) para `SocketException` y `502/503/504`.
- Archivo: `lib/core/network/api_client.dart`

## 2) Validacion ejecutada

Comandos ejecutados:
- `flutter analyze` (frontend): con errores de compilacion `const_with_non_const` en `lib/core/router/app_router.dart` y `test/auth_portal_page_test.dart`.
- `flutter test` (frontend): falla por el mismo problema de constructor no-const en `AuthPortalPage`.
- `.\mvnw.cmd -DskipTests compile` (backend): OK.
- `.\mvnw.cmd test` (backend): fallas de integracion por respuestas `409` en creacion de reservas de tests.

Conclusion:
- Contratos de rutas front/back estan alineados.
- La base es desplegable, pero hay deuda de pruebas/lint para dejar pipeline 100% verde.

## 3) Scripts 1 click creados

### Reinicio local + limpieza de cache
- Boton: `reiniciar_local_todo.bat`
- Script real: `tools/local_reset_bootstrap.ps1`
- Que hace:
  - detiene procesos/puertos locales,
  - limpia cache frontend (`flutter clean` + `flutter pub get`),
  - limpia/compila backend (`mvn clean compile`),
  - relanza stack con `..\deploy_all.ps1 -ForceRestart`.

### Deploy produccion backend + frontend con porcentaje
- Boton: `deploy_produccion_1click.bat`
- Script real: `tools/deploy_production_one_click.ps1`
- Que hace:
  - carga variables desde Azure Key Vault al proceso,
  - compila backend (smoke),
  - despliega backend prod a Cloud Run,
  - compila frontend web con `API_BASE_URL` del backend desplegado,
  - despliega frontend a Cloud Run,
  - imprime URLs finales.

Modo simulacion (sin ejecutar cambios remotos):
```powershell
powershell -ExecutionPolicy Bypass -File .\tools\deploy_production_one_click.ps1 -NoExecute
```

## 4) Links y URIs operativas

### Local
- Backend base: `http://localhost:8080`
- API v1: `http://localhost:8080/api/v1`
- Front web local (default): `http://127.0.0.1:8088`

### Cloud Run (se resuelven automaticamente en deploy)
- Backend service esperado: `travelbox-backend-prod`
- Frontend service esperado: `travelbox-frontend-prod`
- Region default: `us-central1`

### Archivos de configuracion relevantes
- Backend prod env: `..\cloudrun-backend-env.prod.yaml`
- Backend qa env: `..\cloudrun-backend-env.qa.yaml`
- Deploy backend cloud: `..\tools\deploy_cloudrun_backend.ps1`
- Orquestador local full stack: `..\deploy_all.ps1`

### Azure Key Vault
- Vault endpoint: `https://kvtravelboxpe.vault.azure.net/`
- Secrets de Facebook usados:
  - `tbx-auth-facebook-app-id`
  - `tbx-auth-facebook-app-secret`
  - `tbx-app-firebase-facebook-enabled`

## 5) Nota importante para produccion

Antes del deploy real, completa `AZURE_CLIENT_SECRET` en:
- `..\cloudrun-backend-env.prod.yaml`

Si ese valor esta vacio, el script de deploy bloquea la ejecucion para evitar un despliegue incompleto.
