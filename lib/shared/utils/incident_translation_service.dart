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

  String _cacheKey({
    required String message,
    required String sourceLanguage,
    required String customerLanguage,
  }) {
    return '${sourceLanguage.trim().toLowerCase()}|'
        '${customerLanguage.trim().toLowerCase()}|'
        '${message.trim()}';
  }
}
