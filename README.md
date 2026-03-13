# TravelBox Peru App (Flutter Frontend)

Frontend completo en Flutter para plataforma de almacenamiento turistico:
- App cliente (onboarding, auth, discovery mapa/lista, reserva, checkout, QR, tracking, incidencias, perfil).
- Panel admin/operativo web (dashboard, operacion de almacenes, reservas, incidencias).
  - Admin: dashboard, almacenes, reservas, incidencias, historial de pagos, usuarios/roles.
  - Operativo: panel simple de atencion (cobros en caja, reservas operativas, incidencias).
- Integracion lista para backend Java (Spring Boot) por API REST versionada.

## Documentacion principal

- Blueprint funcional y tecnico completo:
  - `..\TravelBox_Peru_Backend\docs\travelbox-platform-blueprint.md`
- Manual de simulacion operativa:
  - `docs\simulation-ui-manual.md`
- Manual de despliegue QA multiplataforma:
  - `docs\deployment-qa-multiplatform-manual.md`
- Flujo QR + PIN (presencial y delivery):
  - `docs\qr-pin-handoff-workflow.md`
- Manual operativo backend:
  - `..\TravelBox_Peru_Backend\docs\operation-simulation-manual.md`

## Stack
- Flutter 3.41.4 (via Puro)
- Riverpod
- go_router
- Dio
- flutter_map + OSM
- i18n ES/EN/DE/FR/IT/PT
- Tests unitarios y widget

## Instalacion / setup
1. Instalar Flutter estable (ya realizado en este equipo con Puro).
2. En el proyecto ejecutar:

```powershell
& "C:\Users\GianLH\AppData\Local\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" -e stable flutter pub get
```

## Ejecutar app

### Web (recomendado para panel admin/operativo)
```powershell
& "C:\Users\GianLH\AppData\Local\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" -e stable flutter run -d chrome
```

### Android
```powershell
& "C:\Users\GianLH\AppData\Local\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" -e stable flutter build apk --release
```

SDK Android local configurado en este equipo:
- `C:\Users\GianLH\Desktop\PROYECTI\android-sdk`
- AVD creado: `TravelBox_API_35`
- Script de arranque:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_android_emulator.ps1
```

APK debug validado:
- `build\app\outputs\flutter-apk\app-debug.apk`

### Windows Desktop (cuando tengas Visual Studio + Developer Mode)
```powershell
& "C:\Users\GianLH\AppData\Local\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" -e stable flutter build windows
```

### Con backend Java real (sin fallback mock)
```powershell
& "C:\Users\GianLH\AppData\Local\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" -e stable flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api/v1 --dart-define=USE_MOCK_FALLBACK=false
```

## Pruebas y calidad
```powershell
& "C:\Users\GianLH\AppData\Local\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" -e stable flutter analyze
& "C:\Users\GianLH\AppData\Local\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" -e stable flutter test
& "C:\Users\GianLH\AppData\Local\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" -e stable flutter build web --release
```

## Contrato API integrado (backend Java MVP)
Base URL:
- `API_BASE_URL` (default: `http://localhost:8080/api/v1`)

Endpoints consumidos:
- `POST /auth/login`
- `POST /auth/register`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /geo/cities`
- `GET /geo/zones?cityId={id}`
- `GET /warehouses/nearby?latitude={lat}&longitude={lng}` (alias tambien acepta `lat/lng`, fallback `/geo/warehouses/nearby`)
- `GET /warehouses/search` (fallback: `/geo/warehouses/search`)
- `GET /warehouses/{warehouseId}`
- `GET /warehouses/{warehouseId}/availability?startAt=...&endAt=...`
- `POST /reservations`
- `POST /reservations/assisted` (reserva asistida en oficina para operador/admin)
- `GET /reservations/page?page=0&size=20` (principal)
- `Mis reservas` ahora destaca la reserva mas actual y pagina el historial restante.
- `GET /reservations` (fallback; usuario cliente: propias, admin/operativo: todas)
- `GET /reservations/my` (fallback)
- `GET /reservations/{reservationId}`
- `GET /reservations/{reservationId}/qr`
- `PATCH /reservations/{reservationId}/cancel`
- `POST /payments/checkout` (principal)
- `GET /payments/status?paymentIntentId={id}` o `?reservationId={id}`
- `GET /payments/cash/pending?page=0&size=20`
- `POST /payments/cash/{paymentIntentId}/approve`
- `POST /payments/cash/{paymentIntentId}/reject`
- `GET /notifications/my?page=0&size=20`
- `GET /notifications/stream?afterId={id}&limit={n}`
- `POST /payments/intents`
- `POST /payments/confirm`
- `POST /inventory/checkin`
- `POST /inventory/checkout`
- `POST /delivery-orders`
- `GET /geo/route`
- `POST /incidents`
- `POST /ops/qr-handoff/scan`
- `GET /ops/qr-handoff/reservations/{reservationId}`
- `POST /ops/qr-handoff/reservations/{reservationId}/tag`
- `POST /ops/qr-handoff/reservations/{reservationId}/store`
- `POST /ops/qr-handoff/reservations/{reservationId}/ready-for-pickup`
- `POST /ops/qr-handoff/reservations/{reservationId}/pickup/confirm`
- `PATCH /ops/qr-handoff/reservations/{reservationId}/delivery/identity`
- `PATCH /ops/qr-handoff/reservations/{reservationId}/delivery/luggage`
- `POST /ops/qr-handoff/reservations/{reservationId}/delivery/request-approval`
- `GET /ops/qr-handoff/approvals`
- `POST /ops/qr-handoff/approvals/{approvalId}/approve`
- `POST /ops/qr-handoff/reservations/{reservationId}/delivery/complete`
- `GET /admin/dashboard` (fallback aliases: `/dashboard/summary`, `/stats`, `/overview`)
- `GET /admin/users`
- `POST /admin/users`
- `PUT /admin/users/{id}`
- `PATCH /admin/users/{id}/active`
- `PATCH /admin/users/{id}/password`
- `DELETE /admin/users/{id}`

Nota:
- Roles soportados: `CLIENT`, `OPERATOR`, `COURIER`, `CITY_SUPERVISOR`, `ADMIN`, `SUPPORT`.
- El frontend usa refresh token automatico ante `401` y luego reintenta la solicitud original una vez.
- Para `paymentMethod=counter|cash`, el frontend deja el pago en flujo `WAITING_OFFLINE_VALIDATION` y perfiles operativos (`OPERATOR`, `CITY_SUPERVISOR`, `ADMIN`) lo validan desde `Pagos en caja`.
- El rol `SUPPORT` solo accede al modulo de incidencias y contacto con cliente.
- La pantalla de solicitud logistica soporta tanto `DELIVERY` como `PICKUP`; `PICKUP` sirve para recoger equipaje del cliente y llevarlo al almacen.

Campos minimos recomendados en respuesta de reserva:
- `id`, `code`, `userId`, `warehouse`, `startAt`, `endAt`, `bagCount`, `totalPrice`, `status`, `timeline[]`

Campos minimos recomendados en respuesta de almacen:
- `id`, `name`, `address`, `city`, `district`, `latitude`, `longitude`, `openingHours`, `priceFromPerHour`, `score`, `availableSlots`, `extraServices[]`

## Notas de operacion
- Si el backend no responde y `USE_MOCK_FALLBACK=true`, la app sigue operando con datos mock para demo/piloto.
- Credenciales demo operativas:
  - `admin@travelbox.pe / Admin123!`
  - `operator@travelbox.pe / Operator123!`
  - `operator.north@travelbox.pe / Operator123!`
  - `courier@travelbox.pe / Courier123!`
  - `courier.north@travelbox.pe / Courier123!`
  - `support@travelbox.pe / Support123!`
  - `client@travelbox.pe / Client123!`
- En login mock:
  - email con `admin` => rol admin
  - email con `oper` => rol operador
  - email con `support` => rol support
  - otro email => rol client
- Estado toolchain local actual:
  - Web: validado y build OK.
  - Android: pendiente instalar Android SDK.
  - Windows desktop: pendiente Visual Studio + Developer Mode de Windows.
