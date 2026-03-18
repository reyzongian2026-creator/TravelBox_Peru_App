class BidirectionalTranslation {
  const BidirectionalTranslation({
    required this.messageInSpanish,
    required this.messageForCustomerLanguage,
    required this.customerLanguage,
    required this.sourceLanguage,
  });

  final String messageInSpanish;
  final String messageForCustomerLanguage;
  final String customerLanguage;
  final String sourceLanguage;
}

BidirectionalTranslation translateBidirectionalMessage({
  required String originalMessage,
  required String sourceLanguage,
  required String customerLanguage,
}) {
  final normalizedSource = _normalizeLang(sourceLanguage);
  final normalizedCustomer = _normalizeLang(customerLanguage);
  final source = originalMessage.trim();
  if (source.isEmpty) {
    return BidirectionalTranslation(
      messageInSpanish: '',
      messageForCustomerLanguage: '',
      customerLanguage: normalizedCustomer,
      sourceLanguage: normalizedSource,
    );
  }

  final spanish = normalizedSource == 'es'
      ? source
      : translateToSpanish(
          sourceMessage: source,
          sourceLanguage: normalizedSource,
        );

  final customerText = normalizedCustomer == 'es'
      ? spanish
      : translateAdminMessage(
          messageInSpanish: spanish,
          targetLanguage: normalizedCustomer,
        );

  return BidirectionalTranslation(
    messageInSpanish: spanish,
    messageForCustomerLanguage: customerText,
    customerLanguage: normalizedCustomer,
    sourceLanguage: normalizedSource,
  );
}

String translateToSpanish({
  required String sourceMessage,
  required String sourceLanguage,
}) {
  final source = sourceMessage.trim();
  if (source.isEmpty) {
    return '';
  }
  final lang = _normalizeLang(sourceLanguage);
  if (lang == 'es') {
    return source;
  }

  final normalized = _normalizeSentence(source);
  final map = _spanishFromForeignDictionary[lang];
  if (map != null && map.containsKey(normalized)) {
    return map[normalized]!;
  }

  var translated = source;
  for (final entry in _foreignToSpanishWordMap.entries) {
    translated = translated.replaceAll(
      RegExp('\\b${entry.key}\\b', caseSensitive: false),
      entry.value,
    );
  }
  return '[ES] $translated';
}

String translateAdminMessage({
  required String messageInSpanish,
  required String targetLanguage,
}) {
  final source = messageInSpanish.trim();
  if (source.isEmpty) {
    return '';
  }
  final lang = _normalizeLang(targetLanguage);
  if (lang == 'es') {
    return source;
  }

  final normalized = _normalizeSentence(source);
  final map = _translationDictionary[lang] ?? _translationDictionary['en']!;
  if (map.containsKey(normalized)) {
    return map[normalized]!;
  }

  var translated = source;
  for (final entry in _spanishToEnglishWordMap.entries) {
    translated = translated.replaceAll(
      RegExp('\\b${entry.key}\\b', caseSensitive: false),
      _translatedWord(entry.value, lang),
    );
  }
  return '[${lang.toUpperCase()}] $translated';
}

String languageLabel(String languageCode) {
  switch (_normalizeLang(languageCode)) {
    case 'es':
      return 'Español';
    case 'en':
      return 'English';
    case 'de':
      return 'Deutsch';
    case 'fr':
      return 'Français';
    case 'it':
      return 'Italiano';
    case 'pt':
      return 'Português';
    default:
      return languageCode.toUpperCase();
  }
}

String _normalizeLang(String languageCode) {
  final normalized = languageCode.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'es';
  }
  if (normalized.length <= 2) {
    return normalized;
  }
  return normalized.substring(0, 2);
}

String _normalizeSentence(String text) {
  return text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}

const _spanishToEnglishWordMap = <String, String>{
  'hola': 'hello',
  'reserva': 'reservation',
  'maleta': 'luggage',
  'qr': 'qr',
  'código': 'code',
  'codigo': 'code',
  'pin': 'pin',
  'operador': 'operator',
  'entrega': 'handoff',
  'confirmar': 'confirm',
  'validar': 'validate',
  'cliente': 'customer',
  'aprobación': 'approval',
  'aprobacion': 'approval',
};

const _foreignToSpanishWordMap = <String, String>{
  'hello': 'hola',
  'reservation': 'reserva',
  'luggage': 'maleta',
  'code': 'código',
  'pin': 'pin',
  'operator': 'operador',
  'handoff': 'entrega',
  'confirm': 'confirmar',
  'validate': 'validar',
  'customer': 'cliente',
  'approval': 'aprobación',
  'bonjour': 'hola',
  'ciao': 'hola',
  'ola': 'hola',
};

String _translatedWord(String englishWord, String lang) {
  switch (lang) {
    case 'de':
      return _deWords[englishWord] ?? englishWord;
    case 'fr':
      return _frWords[englishWord] ?? englishWord;
    case 'it':
      return _itWords[englishWord] ?? englishWord;
    case 'pt':
      return _ptWords[englishWord] ?? englishWord;
    default:
      return englishWord;
  }
}

const _deWords = <String, String>{
  'hello': 'hallo',
  'reservation': 'reservierung',
  'luggage': 'gepäck',
  'code': 'code',
  'pin': 'pin',
  'operator': 'operator',
  'handoff': 'übergabe',
  'confirm': 'bestätigen',
  'validate': 'validieren',
  'customer': 'kunde',
  'approval': 'freigabe',
};

const _frWords = <String, String>{
  'hello': 'bonjour',
  'reservation': 'réservation',
  'luggage': 'bagage',
  'code': 'code',
  'pin': 'pin',
  'operator': 'opérateur',
  'handoff': 'remise',
  'confirm': 'confirmer',
  'validate': 'valider',
  'customer': 'client',
  'approval': 'approbation',
};

const _itWords = <String, String>{
  'hello': 'ciao',
  'reservation': 'prenotazione',
  'luggage': 'bagaglio',
  'code': 'codice',
  'pin': 'pin',
  'operator': 'operatore',
  'handoff': 'consegna',
  'confirm': 'confermare',
  'validate': 'validare',
  'customer': 'cliente',
  'approval': 'approvazione',
};

const _ptWords = <String, String>{
  'hello': 'olá',
  'reservation': 'reserva',
  'luggage': 'bagagem',
  'code': 'código',
  'pin': 'pin',
  'operator': 'operador',
  'handoff': 'entrega',
  'confirm': 'confirmar',
  'validate': 'validar',
  'customer': 'cliente',
  'approval': 'aprovação',
};

const _translationDictionary = <String, Map<String, String>>{
  'en': {
    'hola, por favor presenta tu qr para validar tu reserva y maleta.':
        'Hello, please show your QR to validate your reservation and luggage.',
    'tu entrega fue validada. comparte este pin con el operador o courier para completar.':
        'Your handoff was validated. Share this PIN with the operator or courier to complete.',
    'el operador necesita aprobar la entrega. te avisaremos cuando este listo.':
        'The operator needs to approve the handoff. We will notify you when it is ready.',
    'tu reserva esta lista para recojo. presenta tu qr y pin de seguridad.':
        'Your reservation is ready for pickup. Show your QR and security PIN.',
  },
  'de': {
    'hola, por favor presenta tu qr para validar tu reserva y maleta.':
        'Hallo, bitte zeigen Sie Ihren QR-Code, um Reservierung und Gepäck zu validieren.',
    'tu entrega fue validada. comparte este pin con el operador o courier para completar.':
        'Ihre Übergabe wurde validiert. Teilen Sie diesen PIN mit dem Operator oder Kurier, um abzuschließen.',
    'el operador necesita aprobar la entrega. te avisaremos cuando este listo.':
        'Der Operator muss die Übergabe genehmigen. Wir informieren Sie, sobald sie bereit ist.',
    'tu reserva esta lista para recojo. presenta tu qr y pin de seguridad.':
        'Ihre Reservierung ist zur Abholung bereit. Zeigen Sie Ihren QR-Code und Sicherheits-PIN.',
  },
  'fr': {
    'hola, por favor presenta tu qr para validar tu reserva y maleta.':
        'Bonjour, veuillez présenter votre QR pour valider votre réservation et vos bagages.',
    'tu entrega fue validada. comparte este pin con el operador o courier para completar.':
        'Votre remise a été validée. Partagez ce PIN avec l opérateur ou le coursier pour finaliser.',
    'el operador necesita aprobar la entrega. te avisaremos cuando este listo.':
        'L opérateur doit approuver la remise. Nous vous informerons quand ce sera prêt.',
    'tu reserva esta lista para recojo. presenta tu qr y pin de seguridad.':
        'Votre réservation est prête pour le retrait. Présentez votre QR et votre PIN de sécurité.',
  },
  'it': {
    'hola, por favor presenta tu qr para validar tu reserva y maleta.':
        'Ciao, mostra il tuo QR per convalidare prenotazione e bagaglio.',
    'tu entrega fue validada. comparte este pin con el operador o courier para completar.':
        'La tua consegna è stata validata. Condividi questo PIN con operatore o corriere per completare.',
    'el operador necesita aprobar la entrega. te avisaremos cuando este listo.':
        'L operatore deve approvare la consegna. Ti avviseremo quando sarà pronta.',
    'tu reserva esta lista para recojo. presenta tu qr y pin de seguridad.':
        'La tua prenotazione è pronta per il ritiro. Mostra QR e PIN di sicurezza.',
  },
  'pt': {
    'hola, por favor presenta tu qr para validar tu reserva y maleta.':
        'Olá, por favor apresente seu QR para validar sua reserva e bagagem.',
    'tu entrega fue validada. comparte este pin con el operador o courier para completar.':
        'Sua entrega foi validada. Compartilhe este PIN com o operador ou courier para concluir.',
    'el operador necesita aprobar la entrega. te avisaremos cuando este listo.':
        'O operador precisa aprovar a entrega. Avisaremos quando estiver pronta.',
    'tu reserva esta lista para recojo. presenta tu qr y pin de seguridad.':
        'Sua reserva está pronta para retirada. Apresente QR e PIN de segurança.',
  },
};

const _spanishFromForeignDictionary = <String, Map<String, String>>{
  'en': {
    'hello, please show your qr to validate your reservation and luggage.':
        'Hola, por favor presenta tu QR para validar tu reserva y maleta.',
    'your handoff was validated. share this pin with the operator or courier to complete.':
        'Tu entrega fue validada. Comparte este PIN con el operador o courier para completar.',
    'the operator needs to approve the handoff. we will notify you when it is ready.':
        'El operador necesita aprobar la entrega. Te avisaremos cuando esté listo.',
    'your reservation is ready for pickup. show your qr and security pin.':
        'Tu reserva está lista para recojo. Presenta tu QR y PIN de seguridad.',
  },
  'de': {
    'hallo, bitte zeigen sie ihren qr-code, um reservierung und gepack zu validieren.':
        'Hola, por favor presenta tu QR para validar tu reserva y maleta.',
  },
  'fr': {
    'bonjour, veuillez presenter votre qr pour valider votre reservation et vos bagages.':
        'Hola, por favor presenta tu QR para validar tu reserva y maleta.',
  },
  'it': {
    'ciao, mostra il tuo qr per convalidare prenotazione e bagaglio.':
        'Hola, por favor presenta tu QR para validar tu reserva y maleta.',
  },
  'pt': {
    'ola, por favor apresente seu qr para validar sua reserva e bagagem.':
        'Hola, por favor presenta tu QR para validar tu reserva y maleta.',
  },
};
