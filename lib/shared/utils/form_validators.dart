import '../../core/l10n/app_localizations.dart';

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
    AppLocalizations? l10n,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _msg6('Ingresa este campo.', 'Enter this field.',
        'Geben Sie dieses Feld ein.', 'Entrez ce champ.', 'Inserisci questo campo.',
        'Preencha este campo.', l10n);
    }
    if (text.length < minLength) {
      return _msg6(
        'Debe tener al menos $minLength caracteres.',
        'Must be at least $minLength characters.',
        'Muss mindestens $minLength Zeichen haben.',
        'Doit avoir au moins $minLength caracteres.',
        'Deve avere almeno $minLength caratteri.',
        'Deve ter pelo menos $minLength caracteres.',
        l10n,
      );
    }
    return null;
  }

  static String? email(String? value, {bool required = true, AppLocalizations? l10n}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return required
          ? _msg6('Ingresa un correo valido.', 'Enter a valid email.',
              'Geben Sie eine gultige E-Mail ein.', 'Entrez un email valide.',
              'Inserisci un email valido.', 'Digite um email valido.', l10n)
          : null;
    }
    if (!_emailPattern.hasMatch(text)) {
      return _msg6('Ingresa un correo valido.', 'Enter a valid email.',
          'Geben Sie eine gultige E-Mail ein.', 'Entrez un email valide.',
          'Inserisci un email valido.', 'Digite um email valido.', l10n);
    }
    return null;
  }

  static String? phone(
    String? value, {
    bool required = true,
    String label = 'un telefono valido',
    AppLocalizations? l10n,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return required
          ? _msg6('Ingresa un telefono valido.', 'Enter a valid phone number.',
              'Geben Sie eine gultige Telefonnummer ein.', 'Entrez un numero de telephone valide.',
              'Inserisci un numero di telefono valido.', 'Digite um numero de telefone valido.', l10n)
          : null;
    }
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return _msg6('Ingresa un telefono valido.', 'Enter a valid phone number.',
          'Geben Sie eine gultige Telefonnummer ein.', 'Entrez un numero de telephone valide.',
          'Inserisci un numero di telefono valido.', 'Digite um numero de telefone valido.', l10n);
    }
    return null;
  }

  static String? password(String? value, {bool required = true, AppLocalizations? l10n}) {
    final text = value ?? '';
    if (text.isEmpty) {
      return required
          ? _msg6('Ingresa tu contrasena.', 'Enter your password.',
              'Geben Sie Ihr Passwort ein.', 'Entrez votre mot de passe.',
              'Inserisci la tua password.', 'Digite sua senha.', l10n)
          : null;
    }
    if (text.length < 8) {
      return _msg6(
        'La contrasena debe tener al menos 8 caracteres.',
        'Password must be at least 8 characters.',
        'Das Passwort muss mindestens 8 Zeichen haben.',
        'Le mot de passe doit avoir au moins 8 caracteres.',
        'La password deve avere almeno 8 caratteri.',
        'A senha deve ter pelo menos 8 caracteres.',
        l10n,
      );
    }
    if (!_passwordHasLetter.hasMatch(text) ||
        !_passwordHasDigit.hasMatch(text)) {
      return _msg6(
        'La contrasena debe incluir letras y numeros.',
        'Password must include letters and numbers.',
        'Das Passwort muss Buchstaben und Zahlen enthalten.',
        'Le mot de passe doit contenir des lettres et des chiffres.',
        'La password deve contenere lettere e numeri.',
        'A senha deve conter letras e numeros.',
        l10n,
      );
    }
    return null;
  }

  static String? strongPassword(String? value, {bool required = true, AppLocalizations? l10n}) {
    final text = value ?? '';
    if (text.isEmpty) {
      return required
          ? _msg6('Ingresa tu contrasena.', 'Enter your password.',
              'Geben Sie Ihr Passwort ein.', 'Entrez votre mot de passe.',
              'Inserisci la tua password.', 'Digite sua senha.', l10n)
          : null;
    }
    if (text.length < 8) {
      return _msg6(
        'La contrasena debe tener al menos 8 caracteres.',
        'Password must be at least 8 characters.',
        'Das Passwort muss mindestens 8 Zeichen haben.',
        'Le mot de passe doit avoir au moins 8 caracteres.',
        'La password deve avere almeno 8 caratteri.',
        'A senha deve ter pelo menos 8 caracteres.',
        l10n,
      );
    }
    if (!_passwordHasUpper.hasMatch(text) ||
        !_passwordHasLower.hasMatch(text) ||
        !_passwordHasDigit.hasMatch(text) ||
        !_passwordHasSymbol.hasMatch(text)) {
      return _msg6(
        'Debe incluir mayuscula, minuscula, numero y simbolo.',
        'Must include uppercase, lowercase, number, and symbol.',
        'Muss Grossbuchstaben, Kleinbuchstaben, Zahlen und Symbole enthalten.',
        'Doit inclure majuscules, minuscules, chiffres et symboles.',
        'Deve includere maiuscole, minuscole, numeri e simboli.',
        'Deve incluir maiusculas, minusculas, numeros e simbolos.',
        l10n,
      );
    }
    return null;
  }

  static String? confirmPassword(String? value, String password, {AppLocalizations? l10n}) {
    final text = value ?? '';
    if (text.isEmpty) {
      return _msg6('Confirma tu contrasena.', 'Confirm your password.',
          'Bestatigen Sie Ihr Passwort.', 'Confirmez votre mot de passe.',
          'Conferma la tua password.', 'Confirme sua senha.', l10n);
    }
    if (text != password) {
      return _msg6('Las contrasenas no coinciden.', 'Passwords do not match.',
          'Passworter stimmen nicht uberein.', 'Les mots de passe ne correspondent pas.',
          'Le password non corrispondono.', 'As senhas nao coincidem.', l10n);
    }
    return null;
  }

  static String? latitude(String? value, {AppLocalizations? l10n}) {
    final parsed = parseDouble(value);
    if (parsed == null) {
      return _msg6(
        'Ingresa una latitud numerica valida.',
        'Enter a valid numeric latitude.',
        'Geben Sie einen gultigen numerischen Breitengrad ein.',
        'Entrez une latitude numerique valide.',
        'Inserisci una latitudine numerica valida.',
        'Digite uma latitude numerica valida.',
        l10n,
      );
    }
    if (parsed < -90 || parsed > 90) {
      return _msg6(
        'La latitud debe estar entre -90 y 90.',
        'Latitude must be between -90 and 90.',
        'Der Breitengrad muss zwischen -90 und 90 liegen.',
        'La latitude doit etre entre -90 et 90.',
        'La latitudine deve essere compresa tra -90 e 90.',
        'A latitude deve estar entre -90 e 90.',
        l10n,
      );
    }
    return null;
  }

  static String? longitude(String? value, {AppLocalizations? l10n}) {
    final parsed = parseDouble(value);
    if (parsed == null) {
      return _msg6(
        'Ingresa una longitud numerica valida.',
        'Enter a valid numeric longitude.',
        'Geben Sie einen gultigen numerischen Langengrad ein.',
        'Entrez une longitude numerique valide.',
        'Inserisci una longitudine numerica valida.',
        'Digite uma longitude numerica valida.',
        l10n,
      );
    }
    if (parsed < -180 || parsed > 180) {
      return _msg6(
        'La longitud debe estar entre -180 y 180.',
        'Longitude must be between -180 and 180.',
        'Der Langengrad muss zwischen -180 und 180 liegen.',
        'La longitude doit etre entre -180 et 180.',
        'La longitudine deve essere compresa tra -180 e 180.',
        'A longitude deve estar entre -180 e 180.',
        l10n,
      );
    }
    return null;
  }

  static String? positiveInt(String? value, {required String label, AppLocalizations? l10n}) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return _msg6(
        'Ingresa un numero mayor a cero.',
        'Enter a number greater than zero.',
        'Geben Sie eine Zahl grosser als Null ein.',
        'Entrez un nombre superieur a zero.',
        'Inserisci un numero maggiore di zero.',
        'Digite um numero maior que zero.',
        l10n,
      );
    }
    return null;
  }

  static String? hour(String? value, {required String label, AppLocalizations? l10n}) {
    if (parseHourAsMinutes(value) == null) {
      return _msg6(
        'Ingresa una hora con formato HH:mm.',
        'Enter time in HH:mm format.',
        'Geben Sie die Zeit im Format HH:mm ein.',
        'Entrez le temps au format HH:mm.',
        'Inserisci il tempo nel formato HH:mm.',
        'Digite a hora no formato HH:mm.',
        l10n,
      );
    }
    return null;
  }

  static String? hourRange(String? openHour, String? closeHour, {AppLocalizations? l10n}) {
    final open = parseHourAsMinutes(openHour);
    final close = parseHourAsMinutes(closeHour);
    if (open == null || close == null) {
      return null;
    }
    if (close <= open) {
      return _msg6(
        'La hora de cierre debe ser posterior a la apertura.',
        'Closing time must be after opening time.',
        'Die Schlusszeit muss nach der Offnungszeit liegen.',
        'L\'heure de fermeture doit etre apres l\'heure d\'ouverture.',
        'L\'ora di chiusura deve essere successiva all\'ora di apertura.',
        'O horario de fechamento deve ser posterior ao horario de abertura.',
        l10n,
      );
    }
    return null;
  }

  static String? documentNumber(
    String? value, {
    required String documentType,
    bool required = false,
    AppLocalizations? l10n,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return required
          ? _msg6(
              'Ingresa el numero del documento.',
              'Enter the document number.',
              'Geben Sie die Dokumentennummer ein.',
              'Entrez le numero du document.',
              'Inserisci il numero del documento.',
              'Digite o numero do documento.',
              l10n,
            )
          : null;
    }
    switch (documentType) {
      case 'DNI':
        if (!RegExp(r'^\d{8}$').hasMatch(text)) {
          return _msg6(
            'El DNI debe tener 8 digitos.',
            'DNI must have 8 digits.',
            'Die DNI muss 8 Ziffern haben.',
            'Le DNI doit avoir 8 chiffres.',
            'Il DNI deve avere 8 cifre.',
            'O DNI deve ter 8 digitos.',
            l10n,
          );
        }
        return null;
      case 'PASSPORT':
        if (!RegExp(r'^[A-Za-z0-9]{6,12}$').hasMatch(text)) {
          return _msg6(
            'El pasaporte debe tener entre 6 y 12 caracteres.',
            'Passport must have 6 to 12 characters.',
            'Der Reisepass muss 6 bis 12 Zeichen haben.',
            'Le passeport doit avoir entre 6 et 12 caracteres.',
            'Il passaporto deve avere tra 6 e 12 caratteri.',
            'O passaporte deve ter entre 6 e 12 caracteres.',
            l10n,
          );
        }
        return null;
      case 'FOREIGNER_CARD':
      case 'ID_CARD':
      case 'DRIVER_LICENSE':
      case 'OTHER':
        if (!_documentAlphaNumeric.hasMatch(text)) {
          return _msg6(
            'Ingresa un documento valido.',
            'Enter a valid document number.',
            'Geben Sie eine gultige Dokumentennummer ein.',
            'Entrez un numero de document valide.',
            'Inserisci un numero di documento valido.',
            'Digite um numero de documento valido.',
            l10n,
          );
        }
        return null;
      default:
        return null;
    }
  }

  static String _msg6(
    String es,
    String en,
    String de,
    String fr,
    String it,
    String pt,
    AppLocalizations? l10n,
  ) {
    if (l10n == null) return en;
    switch (l10n.locale.languageCode) {
      case 'es': return es;
      case 'en': return en;
      case 'de': return de;
      case 'fr': return fr;
      case 'it': return it;
      case 'pt': return pt;
      default: return en;
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