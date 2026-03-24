# Flutter Web SDK Fix - Guía de Resolución

## Problema
```
Error: SDK root directory not found: ../../../.puro/envs/stable/flutter/bin/cache/flutter_web_sdk/
```

El cache de Flutter Web SDK está corrupto o no fue inicializado correctamente.

## Soluciones Disponibles

### Opción 1: Usar el nuevo script (RECOMENDADO)
Ejecuta uno de estos scripts `.bat`:

#### `fix_and_deploy_production.bat`
- Repara el Flutter SDK
- Compila el frontend en modo Release
- Inicia servidores frontend y backend
- **Tiempo estimado**: 5-10 minutos

#### `fix_deep_and_deploy_production.bat`
- Limpieza completa de directorios build y cache
- Detiene procesos de Flutter/Chrome en ejecución
- Regenera cache de Flutter Web SDK (doble verificación)
- Resuelve conflictos de dependencias automáticamente
- **Tiempo estimado**: 10-15 minutos
- **Recomendado si**: Los scripts anteriores fallan

### Opción 2: Comando manual paso a paso
```batch
cd C:\Users\GianLH\Desktop\PROYECTI\TravelBox_Peru_App

REM Paso 1: Limpiar
flutter clean

REM Paso 2: Habilitare web
flutter config --enable-web

REM Paso 3: Regenerar cache de web SDK
flutter precache --web --force-download

REM Paso 4: Obtener dependencias
flutter pub get

REM Paso 5: Compilar
flutter build web --release

REM Paso 6: Iniciar servidor (en nueva ventana)
cd build\web
python -m http.server 8080
```

## Si aún hay problemas

### Conflictos de Dependencias
Si ves: "28 packages have newer versions incompatible with dependency constraints"

Ejecuta:
```batch
flutter pub upgrade
flutter pub get
```

### Cache de Puro corrupto
Si persiste el error de SDK:
```batch
cd %USERPROFILE%\.puro\envs\stable\flutter
flutter precache --web --force-download
```

### Última opción: Reset completo
```batch
REM Eliminar cache de flutter completamente
rmdir /s /q %USERPROFILE%\.puro\envs\stable\flutter\bin\cache

REM Regenerar
flutter precache --web --force-download
```

## Verificar que está funcionando

1. **Frontend**: Abre http://localhost:8080 en el navegador
2. **Backend**: Verifica que Spring Boot está ejecutándose en http://localhost:8080/api
3. **Logs**: Revisa las ventanas de terminal para errores

## Archivos importantes

- `pubspec.yaml` - Dependencias de Flutter
- `.dart_tool/` - Cache de compilación (se regenera automáticamente)
- `build/web/` - Output compilado del frontend

## Notas

- Los scripts crean nuevas ventanas de terminal para los servidores
- Debes tener Flutter SDK instalado correctamente (via .puro o similar)
- Python 3.x es necesario para el servidor web
- Maven es necesario para compilar el backend
