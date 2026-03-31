import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'internal_message_translator.dart';

final incidentTranslationServiceProvider = Provider<IncidentTranslationService>(
  (ref) => IncidentTranslationService(),
);

class IncidentTranslationService {
  static const int _maxEntries = 512;

  final LinkedHashMap<String, BidirectionalTranslation> _cache =
      LinkedHashMap<String, BidirectionalTranslation>();

  BidirectionalTranslation translate({
    required String message,
    required String sourceLanguage,
    required String customerLanguage,
  }) {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      return BidirectionalTranslation(
        messageInSpanish: '',
        messageForCustomerLanguage: '',
        customerLanguage: customerLanguage,
        sourceLanguage: sourceLanguage,
      );
    }

    final key = _cacheKey(
      message: normalizedMessage,
      sourceLanguage: sourceLanguage,
      customerLanguage: customerLanguage,
    );
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }

    final translated = translateBidirectionalMessage(
      originalMessage: normalizedMessage,
      sourceLanguage: sourceLanguage,
      customerLanguage: customerLanguage,
    );
    _cache[key] = translated;
    if (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return translated;
  }

  String detectLikelySourceLanguage({
    required String message,
    required String fallbackLanguage,
  }) {
    final normalized = message.trim().toLowerCase();
    if (normalized.isEmpty) {
      return _normalizeLanguage(fallbackLanguage);
    }

    final scored = <String, int>{
      'en': _scoreMarkers(normalized, const [
        'why',
        'cancel',
        'reservation',
        'damage',
        'delay',
        'payment',
        'ticket',
        'hello',
        'please',
        'bag',
      ]),
      'pt': _scoreMarkers(normalized, const [
        'ola',
        'reserva',
        'bagagem',
        'pagamento',
        'atraso',
        'maleta',
      ]),
      'fr': _scoreMarkers(normalized, const [
        'bonjour',
        'reservation',
        'bagage',
        'paiement',
        'retard',
      ]),
      'it': _scoreMarkers(normalized, const [
        'ciao',
        'prenotazione',
        'bagaglio',
        'pagamento',
        'ritardo',
      ]),
      'de': _scoreMarkers(normalized, const [
        'hallo',
        'reservierung',
        'gepack',
        'zahlung',
        'verspatung',
      ]),
      'es': _scoreMarkers(normalized, const [
        'hola',
        'reserva',
        'maleta',
        'pago',
        'retraso',
        'danio',
      ]),
    };

    final best = scored.entries.reduce(
      (current, next) => next.value > current.value ? next : current,
    );
    if (best.value <= 0) {
      return _normalizeLanguage(fallbackLanguage);
    }
    return best.key;
  }

  String _cacheKey({
    required String message,
    required String sourceLanguage,
    required String customerLanguage,
  }) {
    return '${sourceLanguage.trim().toLowerCase()}|'
        '${customerLanguage.trim().toLowerCase()}|'
        '${message.trim()}';
  }

  int _scoreMarkers(String text, List<String> markers) {
    var score = 0;
    for (final marker in markers) {
      if (text.contains(marker)) {
        score += 1;
      }
    }
    return score;
  }

  String _normalizeLanguage(String rawLanguage) {
    final normalized = rawLanguage.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'es';
    }
    if (normalized.length <= 2) {
      return normalized;
    }
    return normalized.substring(0, 2);
  }
}
