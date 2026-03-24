# Azure AD B2C Setup Guide

## Paso 1: Crear Tenant de Azure AD B2C

1. Ve a [Azure Portal](https://portal.azure.com)
2. Busca **"Azure AD B2C"** en el buscador
3. Click **"Create a new Azure AD B2C Tenant"**
4. Rellena los datos:
   - **Organization name**: TravelBoxPeru
   - **Initial domain name**: `travelboxperub2c` (será `travelboxperub2c.onmicrosoft.com`)
   - **Country/Region**: United States
   - **Subscription**: Azure subscription 1
   - **Resource group**: travelbox-peru-rg
5. Click **Review + Create** → **Create**
6. Espera ~2-3 minutos hasta que termine

## Paso 2: Configurar Google como Identity Provider

1. Una vez creado el tenant B2C, entra al mismo
2. En el menú lateral busca **"Identity providers"**
3. Click **"New OpenID Connect provider"**
4. Rellena:
   - **Name**: Google
   - **Metadata URL**: `https://accounts.google.com/.well-known/openid-configuration`
   - **Client ID**: (tu client ID de Google Cloud Console)
   - **Client secret**: (tu client secret de Google Cloud Console)
5. Click **Save**

### Para obtener Google Client ID/Secret:
1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Selecciona el proyecto `travelboxperu-f96ee`
3. Ve a **APIs & Services** → **Credentials**
4. Crea un **OAuth 2.0 Client ID** (Web application)
5. Agrega como authorized redirect URI: `https://travelboxperub2c.b2clogin.com/travelboxperub2c.onmicrosoft.com/oauth2/authresp`

## Paso 3: Configurar Facebook como Identity Provider

1. En **Identity providers** → **New OpenID Connect provider**
2. Rellena:
   - **Name**: Facebook
   - **Metadata URL**: `https://www.facebook.com/.well-known/openid-configuration`
   - **Client ID**: (tu Facebook App ID)
   - **Client secret**: (tu Facebook App Secret)
3. Click **Save**

### Para obtener Facebook App ID/Secret:
1. Ve a [Facebook Developers](https://developers.facebook.com/)
2. Crea una app tipo **Consumer**
3. Agrega **Facebook Login** como producto
4. En settings de Facebook Login, agrega redirect URI: `https://travelboxperub2c.b2clogin.com/travelboxperub2c.onmicrosoft.com/oauth2/authresp`

## Paso 4: Registrar la aplicación Flutter

1. En el tenant B2C, ve a **App registrations** → **New registration**
2. Rellena:
   - **Name**: TravelBox Flutter App
   - **Supported account types**: Accounts in any identity provider or organizational directory (for federated authentication)
   - **Redirect URI**: 
     - Platform: **Web**
     - URL: `https://travelbox-frontend-prod.azurewebsites.net`
3. Click **Register**
4. Anota el **Application (client) ID**

5. Ve a **Authentication** → **Implicit grant and hybrid flows**
6. Marca **ID tokens (used for implicit and hybrid flows)**
7. Click **Save**

8. Ve a **App roles** → **Create app role**
9. Rellena:
   - **Display name**: User
   - **Allowed member types**: Users
   - **Value**: User
   - **Description**: Standard user role

## Paso 5: Obtener Configuration del B2C

1. Ve a **Azure AD B2C** → **App registrations**
2. Selecciona la app creada
3. Click **Endpoints** en el menu superior
4. Copia el **OpenID Connect discovery document** (terminos en `.well-known/openid-configuration`)
5. Anota:
   - `authorization_endpoint`
   - `token_endpoint`
   - `issuer` (terminará con `/{your-tenant}`)

## Paso 6: Guardar secrets en KeyVault

```bash
# Desde tu terminal local:
az keyvault secret set --vault-name "kvtravelboxpe" --name "tbx-b2c-tenant-id" --value "TU-TENANT-ID"
az keyvault secret set --vault-name "kvtravelboxpe" --name "tbx-b2c-client-id" --value "TU-CLIENT-ID"
az keyvault secret set --vault-name "kvtravelboxpe" --name "tbx-b2c-client-secret" --value "TU-CLIENT-SECRET"
az keyvault secret set --vault-name "kvtravelboxpe" --name "tbx-b2c-domain" --value "travelboxperub2c.onmicrosoft.com"
```

## Paso 7: Actualizar código Flutter

El código actual usa Firebase Auth. Necesitas cambiarlo a Azure AD B2C.

Paquetes a agregar en `pubspec.yaml`:
```yaml
dependencies:
  flutter_auth_native: ^2.0.0  # o similar package para B2C
  msal: ^1.0.0
```

## URLs importantes

- Portal B2C: https://portal.azure.com/#blade/Microsoft_AAD_B2CAdmin/Overview
- B2C Domain: `https://travelboxperub2c.b2clogin.com`

## Verificación

1. Una vez configurado, prueba el login en https://travelbox-frontend-prod.azurewebsites.net
2. Deberías ver opción de login con Google/Facebook/Microsoft
