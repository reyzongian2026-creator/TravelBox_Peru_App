class IncidentI18nCodec {
  static final RegExp _languageMarker = RegExp(
    r'^\[LANG:([A-Za-z]{2})\]\s*',
    caseSensitive: false,
  );

  static String withLanguageMarker({
    required String textInSpanish,
    required String customerLanguage,
  }) {
    final language = _normalizeLanguage(customerLanguage);
    final text = textInSpanish.trim();
    if (text.isEmpty) {
      return '';
    }
    return '[LANG:$language] $text';
  }

  static String stripMarker(String rawText) {
    return rawText.replaceFirst(_languageMarker, '').trim();
  }

  static String customerLanguageFrom(String rawText, {String fallback = 'es'}) {
    final match = _languageMarker.firstMatch(rawText);
    if (match == null) {
      return _normalizeLanguage(fallback);
    }
    return _normalizeLanguage(match.group(1));
  }

  static String _normalizeLanguage(String? rawLanguage) {
    final normalized = (rawLanguage ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'es';
    }
    if (normalized.length <= 2) {
      return normalized;
    }
    return normalized.substring(0, 2);
  }
}
