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
- Mapa central de secretos (front + back):
  - `..\VAULT_SECRETS_MAP.txt`

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

3. Si Windows bloquea plugins por symlinks, activa `Developer Mode`:

```powershell
start ms-settings:developers
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
& "C:\Users\GianLH\AppData\Local\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" -e stable flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080/api/v1 --dart-define=USE_MOCK_FALLBACK=false --dart-define=FORCE_CASH_PAYMENTS_ONLY=true
```

### Con cliente Firebase (Google/Facebook)
```powershell
& "C:\Users\GianLH\AppData\Local\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" -e stable flutter run -d chrome `
  --dart-define=API_BASE_URL=http://localhost:8080/api/v1 `
  --dart-define=USE_MOCK_FALLBACK=false `
  --dart-define=FORCE_CASH_PAYMENTS_ONLY=true `
  --dart-define=FIREBASE_API_KEY=<api-key> `
  --dart-define=FIREBASE_PROJECT_ID=<project-id> `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<sender-id> `
  --dart-define=FIREBASE_AUTH_DOMAIN=<project-id>.firebaseapp.com `
  --dart-define=FIREBASE_WEB_APP_ID=<web-app-id> `
  --dart-define=FIREBASE_ANDROID_APP_ID=<android-app-id> `
  --dart-define=FIREBASE_IOS_APP_ID=<ios-app-id> `
  --dart-define=FIREBASE_IOS_BUNDLE_ID=<ios-bundle-id> `
  --dart-define=FIREBASE_GOOGLE_SERVER_CLIENT_ID=551019035202-3khgoibrmpf8qpets7up6rnond00a83e.apps.googleusercontent.com
```

Opcional cuando actives Storage:
```powershell
--dart-define=FIREBASE_STORAGE_BUCKET=<bucket.appspot.com> --dart-define=FIREBASE_STORAGE_UPLOADS_ENABLED=true
```

Nota para login Google en Android:
- `FIREBASE_GOOGLE_SERVER_CLIENT_ID` debe ser el OAuth Client ID de tipo `Web application` del mismo proyecto Firebase/Google Cloud.
- Sin ese valor, Google login puede caer en fallback y no devolver `idToken` en Android.

## Secretos para despliegue

- Fuente central de variables y nombres de secreto: `..\VAULT_SECRETS_MAP.txt`
- Para frontend, tomar desde ese mapa los `--dart-define` Firebase y `API_BASE_URL`.
- Para backend en cloud, usar `APP_FIREBASE_SERVICE_ACCOUNT_JSON` (no ruta local de archivo).
- Si cambias credenciales en el vault, actualiza el mapa y vuelve a compilar/desplegar.

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
- `POST /auth/firebase/social`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /geo/cities`
- `GET /geo/zones?cityId={id}`
- `GET /warehouses/nearby?latitude={lat}&longitude={lng}` (alias tambien acepta `lat/lng`, fallback `/geo/warehouses/nearby`)
- `GET /warehouses/search` (fallback: `/geo/warehouses/search`)
- `GET /warehouses/{warehouseId}`
- `GET /warehouses/{warehouseId}/availability?startAt=...&endAt=...`
- `GET /warehouses/{warehouseId}/image` (foto real o portada automatica)
- `POST /reservations`
- `POST /reservations/checkout` (creacion + pago atomico)
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
- `POST /payments/{paymentIntentId}/refund`
- `GET /notifications/my?page=0&size=20`
- `GET /notifications/stream?afterId={id}&limit={n}`
- `GET /notifications/events` (SSE en tiempo real)
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
- `POST /ops/qr-handoff/reservations/{reservationId}/store-with-photos`
- `POST /ops/qr-handoff/reservations/{reservationId}/ready-for-pickup`
- `POST /ops/qr-handoff/reservations/{reservationId}/pickup/confirm`
- `PATCH /ops/qr-handoff/reservations/{reservationId}/delivery/identity`
- `PATCH /ops/qr-handoff/reservations/{reservationId}/delivery/luggage`
- `POST /ops/qr-handoff/reservations/{reservationId}/delivery/request-approval`
- `GET /ops/qr-handoff/approvals`
- `POST /ops/qr-handoff/approvals/{approvalId}/approve`
- `POST /ops/qr-handoff/reservations/{reservationId}/delivery/complete`
- `GET /profile/me`
- `PATCH /profile/me`
- `POST /profile/me/photo`
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
- Cliente ahora entra por Firebase (`Google` o `Facebook`); el login por correo/contrasena queda para usuarios internos creados por admin.
- Checkout cliente usa primero `POST /reservations/checkout`; si el pago falla, ya no queda una reserva registrada parcialmente.
- Para `paymentMethod=counter|cash`, el frontend deja el pago en flujo `WAITING_OFFLINE_VALIDATION` y perfiles operativos (`OPERATOR`, `CITY_SUPERVISOR`, `ADMIN`) lo validan desde `Pagos en caja`.
- Cancelacion: si el pago digital ya esta confirmado (`card`, `yape`, `plin`, `wallet`), el frontend dispara `refund` y luego backend cancela automaticamente la reserva.
- El rol `SUPPORT` solo accede al modulo de incidencias y contacto con cliente.
- La pantalla de solicitud logistica soporta tanto `DELIVERY` como `PICKUP`; `PICKUP` sirve para recoger equipaje del cliente y llevarlo al almacen.
- Validaciones logisticas: `PICKUP` solo desde `CONFIRMED`, `DELIVERY` solo desde `STORED`/`READY_FOR_PICKUP`, y no se permite duplicar orden activa por tipo.
- La app escucha SSE en web, Android, iOS y Windows para actualizar estados sin refresh manual, sin polling periodico y sin recargar la pantalla; si el canal se corta, el cliente intenta reconectarse automaticamente.
- Las vistas conectadas al cursor de eventos incluyen reservas cliente, reservas admin/operador, pagos en caja, courier, tracking, QR/PIN e incidencias.
- `Mis reservas` ya no mezcla reservas locales antiguas con las remotas cuando el backend responde; eso evita detalles `404` por ids viejos guardados en local.
- `Detalle de reserva` usa `operationalDetail` del backend para reflejar `ID maleta`, `pickupPin` y fotos del ingreso a almacen sin depender de notificaciones en memoria.
- Admin web puede subir o reemplazar la foto de cada almacen; si no existe una foto real, la tarjeta del almacen muestra una portada automatica por sede.
- Las notificaciones operativas llegan por audiencia: `ADMIN` global, `OPERATOR` por sede, `CITY_SUPERVISOR` por sede, `COURIER` por sede y `SUPPORT` por sede en incidencias.
- Desde `Usuarios operativos`, el admin puede crear usuarios y asignarles una o varias sedes dinamicas para `OPERATOR`, `CITY_SUPERVISOR`, `COURIER` y `SUPPORT`.
- En `Operacion QR y PIN`, al registrar ingreso en almacen la web exige una foto por cada bulto; despues del check-in ese registro queda cerrado y solo se consulta por rol.
- El cliente entra por Firebase y el backend espeja su perfil en Firestore; mientras Firebase Storage siga deshabilitado, la foto de perfil y la portada del almacen quedan con imagen por defecto.
- `correo`, `telefono` y `documento` solo pueden cambiarse 3 veces por campo y el backend notifica el saldo restante.
- Los usuarios internos no editan su propia ficha: el admin los crea/edita desde `Usuarios operativos`, y para `COURIER` la placa del vehiculo es obligatoria.

Campos minimos recomendados en respuesta de reserva:
- `id`, `code`, `userId`, `warehouse`, `startAt`, `endAt`, `bagCount`, `totalPrice`, `status`, `timeline[]`

Campos minimos recomendados en respuesta de almacen:
- `id`, `name`, `address`, `city`, `district`, `latitude`, `longitude`, `openingHours`, `priceFromPerHour`, `score`, `availableSlots`, `extraServices[]`

## Notas de operacion
- `USE_MOCK_FALLBACK` esta en `false` por defecto. Solo activa mocks si lo defines manualmente en pruebas.
- Para mostrar checkout solo en efectivo: `FORCE_CASH_PAYMENTS_ONLY=true`.
- Credenciales demo operativas:
  - `admin@travelbox.pe / Admin123!`
  - `operator@travelbox.pe / Operator123!`
  - `operator.north@travelbox.pe / Operator123!`
  - `operator.demo.multisede@travelbox.pe / Operator123!`
  - `courier@travelbox.pe / Courier123!`
  - `courier.north@travelbox.pe / Courier123!`
  - `courier.demo.multisede@travelbox.pe / Courier123!`
  - `support@travelbox.pe / Support123!`
  - `support.demo.multisede@travelbox.pe / Support123!`
  - `supervisor.demo@travelbox.pe / Supervisor123!`
  - `client@travelbox.pe / Client123!`
- Credenciales por sede:
  - Operadores por sede: `operator.<suffix>@travelbox.pe / Operator123!`
  - Supervisores por sede: usuarios creados por admin desde la web con una o varias sedes asignadas
  - Couriers por sede: `courier.<suffix>@travelbox.pe / Courier123!`
  - Soporte por sede: `support.<suffix>@travelbox.pe / Support123!`
- Credenciales demo multi-sede:
  - `operator.demo.multisede@travelbox.pe / Operator123!` -> Miraflores + La Molina
  - `courier.demo.multisede@travelbox.pe / Courier123!` -> Miraflores + La Molina
  - `support.demo.multisede@travelbox.pe / Support123!` -> Miraflores + La Molina
  - `supervisor.demo@travelbox.pe / Supervisor123!` -> Lima Centro + Miraflores + Barranco
- Sufijos disponibles:
  - `miraflores`, `barranco`, `lima.centro`, `la.molina`, `cusco.plaza`, `arequipa.yanahuara`, `huacachina`, `puno.terminal`, `paracas.muelle`, `nazca.lines`, `trujillo.centro`, `piura.plaza`, `mancora.beach`
- Ejemplo de una sede seed:
  - `operator.puno.terminal@travelbox.pe / Operator123!`
  - `courier.puno.terminal@travelbox.pe / Courier123!`
  - `support.puno.terminal@travelbox.pe / Support123!`
- En login mock:
  - email con `admin` => rol admin
  - email con `oper` => rol operador
  - email con `support` => rol support
  - otro email => rol client
- Estado toolchain local actual:
  - Web: validado y build OK.
  - Android: pendiente instalar Android SDK.
  - Windows desktop: pendiente Visual Studio + Developer Mode de Windows.
