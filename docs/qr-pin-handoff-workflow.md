# Flujo QR + PIN (Presencial y Delivery)

Este documento describe el flujo operativo implementado en `Operacion QR y PIN` (`/ops/qr-handoff`) para perfiles:
- `ADMIN`
- `OPERATOR` / `CITY_SUPERVISOR` / `SUPPORT`
- `COURIER`

## 1. Registro internacional de usuario

En registro y edicion de perfil ahora se captura:
- Pais de registro con prefijo telefonico internacional.
- Numero local validado por pais.
- Idioma preferido del usuario (`es`, `en`, `de`, `fr`, `it`, `pt`).

El telefono se guarda en formato internacional (`+codigo` + numero local).

## 2. Flujo presencial (almacen)

1. Operador escanea QR del cliente o ingresa codigo de reserva.
2. Sistema vincula reserva y genera QR de cliente.
3. Operador genera `ID de maleta` y QR de maleta.
4. Se pega etiqueta/precinto a la maleta y se registra en almacen (`STORED`).
5. Cuando este lista para retiro, se genera PIN y estado `READY_FOR_PICKUP`.
6. En retiro presencial:
   - cliente muestra QR
   - operador verifica maleta
   - cliente entrega PIN
   - operador confirma y cierra reserva (`COMPLETED`).

## 3. Flujo delivery seguro

1. Courier valida identidad de receptor.
2. Courier valida que ID de maleta coincida.
3. Courier solicita aprobacion de operador.
4. Operador recibe notificacion en panel y aprueba.
5. Sistema genera PIN de cierre.
6. Courier solicita PIN al cliente y confirma entrega.
7. Reserva pasa a `COMPLETED`.

## 4. Traduccion interna para mensajes admin

En el modulo QR/PIN:
- Admin/operador escribe mensaje base en espanol.
- Sistema genera version traducida para idioma del cliente.
- La traduccion se usa para mensaje operativo en solicitudes de aprobacion.

Nota: es un traductor interno orientado a operacion (mensajeria corta).

## 5. Panel de aprobaciones

Se agrega una bandeja de aprobaciones en el mismo modulo:
- `Pendiente`: espera validacion operador/admin.
- `Aprobada`: PIN generado y listo para courier.
- `Rechazada`: reservado para extension futura.

Adicionalmente, el panel operativo muestra alerta cuando hay aprobaciones pendientes.

## 6. Alcance tecnico actual

- Implementado en frontend Flutter para operacion local y simulacion end-to-end.
- Estados de reserva se sincronizan usando repositorio actual (`STORED`, `READY_FOR_PICKUP`, `COMPLETED`, `OUT_FOR_DELIVERY`).
- Sin dependencia de lector de camara externo: el escaneo actual es por lectura/copia de payload QR.

## 7. Siguientes mejoras recomendadas

- Integrar lector de camara nativo para QR.
- Persistir casos QR/PIN y aprobaciones en backend.
- Integrar push notifications reales para operador/courier/cliente.
- Reforzar traduccion con proveedor de traduccion externa con auditoria.
