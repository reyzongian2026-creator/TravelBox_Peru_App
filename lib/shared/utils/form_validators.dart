import '../../core/l10n/localization_runtime.dart';

class FormValidators {
  const FormValidators._();

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _passwordHasLetter = RegExp(r'[A-Za-z]');
  static final RegExp _passwordHasDigit = RegExp(r'\d');
  static final RegExp _passwordHasUpper = RegExp(r'[A-Z]');
  static final RegExp _passwordHasLower = RegExp(r'[a-z]');
  static final RegExp _passwordHasSymbol = RegExp(r'[^A-Za-z0-9]');
  static final RegExp _documentAlphaNumeric = RegExp(r'^[A-Za-z0-9\-]{5,20}$');

  static String? requiredText(
    String? value, {
    required String label,
    int minLength = 2,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _msg('Ingresa este campo.', 'Enter this field.');
    }
    if (text.length < minLength) {
      return _msg(
        'Debe tener al menos $minLength caracteres.',
        'Must be at least $minLength characters.',
      );
    }
    return null;
  }

  static String? email(String? value, {bool required = true}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return required
          ? _msg('Ingresa un correo valido.', 'Enter a valid email.')
          : null;
    }
    if (!_emailPattern.hasMatch(text)) {
      return _msg('Ingresa un correo valido.', 'Enter a valid email.');
    }
    return null;
  }

  static String? phone(
    String? value, {
    bool required = true,
    String label = 'un telefono valido',
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return required
          ? _msg('Ingresa un telefono valido.', 'Enter a valid phone number.')
          : null;
    }
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return _msg('Ingresa un telefono valido.', 'Enter a valid phone number.');
    }
    return null;
  }

  static String? password(String? value, {bool required = true}) {
    final text = value ?? '';
    if (text.isEmpty) {
      return required
          ? _msg('Ingresa tu contrasena.', 'Enter your password.')
          : null;
    }
    if (text.length < 8) {
      return _msg(
        'La contrasena debe tener al menos 8 caracteres.',
        'Password must be at least 8 characters.',
      );
    }
    if (!_passwordHasLetter.hasMatch(text) ||
        !_passwordHasDigit.hasMatch(text)) {
      return _msg(
        'La contrasena debe incluir letras y numeros.',
        'Password must include letters and numbers.',
      );
    }
    return null;
  }

  static String? strongPassword(String? value, {bool required = true}) {
    final text = value ?? '';
    if (text.isEmpty) {
      return required
          ? _msg('Ingresa tu contrasena.', 'Enter your password.')
          : null;
    }
    if (text.length < 8) {
      return _msg(
        'La contrasena debe tener al menos 8 caracteres.',
        'Password must be at least 8 characters.',
      );
    }
    if (!_passwordHasUpper.hasMatch(text) ||
        !_passwordHasLower.hasMatch(text) ||
        !_passwordHasDigit.hasMatch(text) ||
        !_passwordHasSymbol.hasMatch(text)) {
      return _msg(
        'Debe incluir mayuscula, minuscula, numero y simbolo.',
        'Must include uppercase, lowercase, number, and symbol.',
      );
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final text = value ?? '';
    if (text.isEmpty) {
      return _msg('Confirma tu contrasena.', 'Confirm your password.');
    }
    if (text != password) {
      return _msg('Las contrasenas no coinciden.', 'Passwords do not match.');
    }
    return null;
  }

  static String? latitude(String? value) {
    final parsed = parseDouble(value);
    if (parsed == null) {
      return _msg(
        'Ingresa una latitud numerica valida.',
        'Enter a valid numeric latitude.',
      );
    }
    if (parsed < -90 || parsed > 90) {
      return _msg(
        'La latitud debe estar entre -90 y 90.',
        'Latitude must be between -90 and 90.',
      );
    }
    return null;
  }

  static String? longitude(String? value) {
    final parsed = parseDouble(value);
    if (parsed == null) {
      return _msg(
        'Ingresa una longitud numerica valida.',
        'Enter a valid numeric longitude.',
      );
    }
    if (parsed < -180 || parsed > 180) {
      return _msg(
        'La longitud debe estar entre -180 y 180.',
        'Longitude must be between -180 and 180.',
      );
    }
    return null;
  }

  static String? positiveInt(String? value, {required String label}) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return _msg(
        'Ingresa un numero mayor a cero.',
        'Enter a number greater than zero.',
      );
    }
    return null;
  }

  static String? hour(String? value, {required String label}) {
    if (parseHourAsMinutes(value) == null) {
      return _msg(
        'Ingresa una hora con formato HH:mm.',
        'Enter time in HH:mm format.',
      );
    }
    return null;
  }

  static String? hourRange(String? openHour, String? closeHour) {
    final open = parseHourAsMinutes(openHour);
    final close = parseHourAsMinutes(closeHour);
    if (open == null || close == null) {
      return null;
    }
    if (close <= open) {
      return _msg(
        'La hora de cierre debe ser posterior a la apertura.',
        'Closing time must be after opening time.',
      );
    }
    return null;
  }

  static String? documentNumber(
    String? value, {
    required String documentType,
    bool required = false,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return required
          ? _msg(
              'Ingresa el numero del documento.',
              'Enter the document number.',
            )
          : null;
    }
    switch (documentType) {
      case 'DNI':
        if (!RegExp(r'^\d{8}$').hasMatch(text)) {
          return _msg(
            'El DNI debe tener 8 digitos.',
            'DNI must have 8 digits.',
          );
        }
        return null;
      case 'PASSPORT':
        if (!RegExp(r'^[A-Za-z0-9]{6,12}$').hasMatch(text)) {
          return _msg(
            'El pasaporte debe tener entre 6 y 12 caracteres.',
            'Passport must have 6 to 12 characters.',
          );
        }
        return null;
      case 'FOREIGNER_CARD':
      case 'ID_CARD':
      case 'DRIVER_LICENSE':
      case 'OTHER':
        if (!_documentAlphaNumeric.hasMatch(text)) {
          return _msg(
            'Ingresa un documento valido.',
            'Enter a valid document number.',
          );
        }
        return null;
      default:
        return null;
    }
  }

  static String _msg(String es, String en) {
    return LocalizationRuntime.isSpanish ? es : en;
  }

  static double? parseDouble(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  static int? parseHourAsMinutes(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.length != 5 || !value.contains(':')) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    if (hh == null || mm == null) return null;
    if (hh < 0 || hh > 23 || mm < 0 || mm > 59) return null;
    return (hh * 60) + mm;
  }
}
