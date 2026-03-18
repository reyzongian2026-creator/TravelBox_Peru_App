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
      return 'Ingresa $label.';
    }
    if (text.length < minLength) {
      return '$label debe tener al menos $minLength caracteres.';
    }
    return null;
  }

  static String? email(String? value, {bool required = true}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return required ? 'Ingresa un correo valido.' : null;
    }
    if (!_emailPattern.hasMatch(text)) {
      return 'Ingresa un correo valido.';
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
      return required ? 'Ingresa $label.' : null;
    }
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Ingresa $label.';
    }
    return null;
  }

  static String? password(String? value, {bool required = true}) {
    final text = value ?? '';
    if (text.isEmpty) {
      return required ? 'Ingresa tu contrasena.' : null;
    }
    if (text.length < 8) {
      return 'La contrasena debe tener al menos 8 caracteres.';
    }
    if (!_passwordHasLetter.hasMatch(text) || !_passwordHasDigit.hasMatch(text)) {
      return 'La contrasena debe incluir letras y numeros.';
    }
    return null;
  }

  static String? strongPassword(String? value, {bool required = true}) {
    final text = value ?? '';
    if (text.isEmpty) {
      return required ? 'Ingresa tu contrasena.' : null;
    }
    if (text.length < 8) {
      return 'La contrasena debe tener al menos 8 caracteres.';
    }
    if (!_passwordHasUpper.hasMatch(text) ||
        !_passwordHasLower.hasMatch(text) ||
        !_passwordHasDigit.hasMatch(text) ||
        !_passwordHasSymbol.hasMatch(text)) {
      return 'Debe incluir mayuscula, minuscula, numero y simbolo.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Confirma tu contrasena.';
    }
    if (text != password) {
      return 'Las contrasenas no coinciden.';
    }
    return null;
  }

  static String? latitude(String? value) {
    final parsed = parseDouble(value);
    if (parsed == null) {
      return 'Ingresa una latitud numerica valida.';
    }
    if (parsed < -90 || parsed > 90) {
      return 'La latitud debe estar entre -90 y 90.';
    }
    return null;
  }

  static String? longitude(String? value) {
    final parsed = parseDouble(value);
    if (parsed == null) {
      return 'Ingresa una longitud numerica valida.';
    }
    if (parsed < -180 || parsed > 180) {
      return 'La longitud debe estar entre -180 y 180.';
    }
    return null;
  }

  static String? positiveInt(String? value, {required String label}) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return '$label debe ser un numero mayor a cero.';
    }
    return null;
  }

  static String? hour(String? value, {required String label}) {
    if (parseHourAsMinutes(value) == null) {
      return '$label debe tener formato HH:mm.';
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
      return 'La hora de cierre debe ser posterior a la apertura.';
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
      return required ? 'Ingresa el numero del documento.' : null;
    }
    switch (documentType) {
      case 'DNI':
        if (!RegExp(r'^\d{8}$').hasMatch(text)) {
          return 'El DNI debe tener 8 digitos.';
        }
        return null;
      case 'PASSPORT':
        if (!RegExp(r'^[A-Za-z0-9]{6,12}$').hasMatch(text)) {
          return 'El pasaporte debe tener entre 6 y 12 caracteres.';
        }
        return null;
      case 'FOREIGNER_CARD':
      case 'ID_CARD':
      case 'DRIVER_LICENSE':
      case 'OTHER':
        if (!_documentAlphaNumeric.hasMatch(text)) {
          return 'Ingresa un documento valido.';
        }
        return null;
      default:
        return null;
    }
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
