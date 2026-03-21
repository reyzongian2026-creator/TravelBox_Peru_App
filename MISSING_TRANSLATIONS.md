# Missing Translations Report

## Translation Keys to Add

### Rating/Reviews (warehouse_ratings_page.dart, rating_widgets.dart)

```dart
// Spanish translations to add in _translations['es']
'rating_title': 'Reseñas',
'rating_subtitle': 'Reseñas - {warehouse}' // with param
'rating_success': 'Reseña enviada exitosamente',
'rating_already_reviewed': '¡Ya has dejado tu reseña!',
'rating_all_reviews': 'Todas las reseñas',
'rating_no_reviews': 'Aún no hay reseñas',
'rating_view_all': 'Ver todas las reseñas',
'rating_verified': 'Verificado',
'rating_experience_question': '¿Cómo fue tu experiencia?',
'rating_experience_hint': 'Cuéntanos más sobre tu experiencia (opcional)',
'rating_submit': 'Enviar reseña',
'rating_user_default': 'Usuario',
```

### Delivery Status (delivery_monitor_page.dart, courier_services_page.dart)

```dart
'status_requested': 'Solicitado',
'status_assigned': 'Asignado',
'status_in_transit': 'En tránsito',
'status_delivered': 'Entregado',
'status_cancelled': 'Cancelado',
```

### Incidents (incidents_page.dart)

```dart
'incident_type_damage': 'Daño',
'incident_type_delay': 'Retraso',
'incident_type_wrong_item': 'Artículo incorrecto',
'incident_type_payment': 'Pago',
'incident_type_other': 'Otro',
```

### QR Workflow (qr_workflow_state_machine.dart)

```dart
'qr_step_scan': 'Escanear QR',
'qr_step_validate': 'Validar reserva',
'qr_step_tag': 'Etiquetar equipajes',
'qr_step_photos': 'Capturar fotos',
'qr_step_store': 'Almacenar',
'qr_step_pin': 'Generar PIN',
'qr_step_delivery': 'Entrega',
'qr_step_completed': 'Completado',
```

### Admin Users (admin_users_page.dart)

```dart
'admin_user_error': 'Error: {message}', // with param
'admin_user_default': 'Usuario',
```

### Notifications (mobile_push_service.dart)

```dart
'notification_channel_name': 'TravelBox Live Events',
'notification_channel_description': 'Actualizaciones operacionales y notificaciones de reservas en tiempo real.',
'notification_default_title': 'TravelBox',
```

### Warehouse/Address (various)

```dart
'warehouse_default_name': 'Almacén',
'address_pending': 'Dirección pendiente',
'address_pending_confirmation': 'Dirección pendiente de confirmación en la app',
'price_per_hour': 'S/{price}/hora',
```

## How to Add Translations

1. Open `lib/core/l10n/app_localizations.dart`
2. Find the `_translations` map for Spanish (`'es'`)
3. Add the missing keys
4. Add English translations in `_translations['en']`
5. Add other languages as needed

## Example Structure

```dart
static final Map<String, Map<String, String>> _translations = {
  'es': {
    // existing translations...
    'rating_title': 'Reseñas',
    'rating_success': 'Reseña enviada exitosamente',
    // ... add new keys here
  },
  'en': {
    // existing translations...
    'rating_title': 'Reviews',
    'rating_success': 'Review submitted successfully',
    // ... add new keys here
  },
  // other languages...
};
```

## Priority

1. **HIGH**: Rating/Review strings (user-facing)
2. **MEDIUM**: Delivery statuses, incident types
3. **LOW**: QR workflow, admin strings (internal use)
