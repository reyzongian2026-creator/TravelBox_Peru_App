# Manual De Despliegue QA (iOS, Android, Web, Windows y Backend)

## 1. Objetivo

Desplegar un entorno de pruebas extremo a extremo para validar:

- app cliente,
- panel web operativo/admin/soporte,
- backend con reglas por sede y notificaciones por eventos.

## 2. Prerrequisitos

- Java 21
- Maven Wrapper (`mvnw` / `mvnw.cmd`)
- Flutter estable (en este equipo via Puro)
- Android SDK + emulador/dispositivo
- Xcode (solo macOS, para iOS)
- Visual Studio con C++ Desktop + Developer Mode (Windows desktop)
- PostgreSQL (si el backend se publica fuera de local)

## 3. Backend para pruebas

### 3.1 Local

```powershell
cd ..\TravelBox_Peru_Backend
.\mvnw.cmd -DskipTests compile
.\mvnw.cmd spring-boot:run
```

Backend queda en:

- `http://localhost:8080/api/v1`

### 3.2 Variables minimas en servidor QA

Usar `.env.example` como base y definir:

- `DB_URL`
- `DB_USERNAME`
- `DB_PASSWORD`
- `APP_JWT_SECRET`
- `APP_PUBLIC_BASE_URL`
- `APP_CORS_ALLOWED_ORIGINS` (dominios web de QA)
- `APP_PAYMENT_PROVIDER=mock` (para pruebas funcionales sin pasarela real)

### 3.2.1 Mapa central de secretos

Usar como fuente unica:

- `..\..\VAULT_SECRETS_MAP.txt`

Regla para cloud:

- Backend: usar `APP_FIREBASE_SERVICE_ACCOUNT_JSON`.
- No depender de `APP_FIREBASE_SERVICE_ACCOUNT_FILE` en servidores cloud.

### 3.3 Donde publicarlo solo para pruebas

Puedes usar cualquier PaaS que soporte Java + PostgreSQL (por ejemplo Render/Railway/Fly.io o un VPS propio).  
Para QA, prioriza:

- despliegue rapido de Spring Boot,
- URL HTTPS publica,
- base de datos separada del entorno productivo,
- rollback simple.

## 4. Frontend apuntando a backend QA

```powershell
cd ..\TravelBox_Peru_App
flutter pub get
```

Siempre pasar:

- `--dart-define=API_BASE_URL=https://TU_BACKEND_QA/api/v1`
- `--dart-define=USE_MOCK_FALLBACK=false`
- y los `--dart-define` Firebase requeridos segun `..\..\VAULT_SECRETS_MAP.txt`
- para Google login en Android agregar `--dart-define=FIREBASE_GOOGLE_SERVER_CLIENT_ID=551019035202-3khgoibrmpf8qpets7up6rnond00a83e.apps.googleusercontent.com`

## 5. Despliegue Web (panel operativo/admin/soporte)

```powershell
flutter build web --release ^
  --dart-define=API_BASE_URL=https://TU_BACKEND_QA/api/v1 ^
  --dart-define=USE_MOCK_FALLBACK=false
```

Publicar carpeta `build/web` en hosting estatico (Nginx, Firebase Hosting, Netlify, Vercel, etc).

## 6. Despliegue Android

```powershell
flutter build apk --release ^
  --dart-define=API_BASE_URL=https://TU_BACKEND_QA/api/v1 ^
  --dart-define=USE_MOCK_FALLBACK=false
```

Salida:

- `build/app/outputs/flutter-apk/app-release.apk`

## 7. Despliegue iOS (solo macOS)

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://TU_BACKEND_QA/api/v1 \
  --dart-define=USE_MOCK_FALLBACK=false
```

Luego subir IPA con Xcode/Transporter a TestFlight (canal QA).

## 8. Despliegue Windows Desktop

```powershell
flutter build windows --release `
  --dart-define=API_BASE_URL=https://TU_BACKEND_QA/api/v1 `
  --dart-define=USE_MOCK_FALLBACK=false
```

Salida:

- `build\windows\x64\runner\Release\`

## 9. Checklist de validacion post-despliegue

1. Login de cada rol (`ADMIN`, `OPERATOR`, `COURIER`, `SUPPORT`, `CLIENT`).
2. Verificar scope por sede:
   - operador/courier solo ven su sede.
3. Crear reserva y validar notificacion en stream (`/notifications/stream`).
4. Validar redireccion desde notificacion al modulo correcto.
5. Abrir incidencia y validar acceso solo en soporte/admin.
6. Ejecutar flujo completo: reserva -> almacen -> delivery -> completado.
