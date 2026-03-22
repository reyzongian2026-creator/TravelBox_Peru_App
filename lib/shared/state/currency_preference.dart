import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CurrencyCode { pen, usd, eur }

extension CurrencyCodeExtension on CurrencyCode {
  String get symbol {
    switch (this) {
      case CurrencyCode.pen:
        return 'S/';
      case CurrencyCode.usd:
        return '\$';
      case CurrencyCode.eur:
        return '€';
    }
  }

  String get code {
    switch (this) {
      case CurrencyCode.pen:
        return 'PEN';
      case CurrencyCode.usd:
        return 'USD';
      case CurrencyCode.eur:
        return 'EUR';
    }
  }

  String get name {
    switch (this) {
      case CurrencyCode.pen:
        return 'Soles';
      case CurrencyCode.usd:
        return 'Dólares';
      case CurrencyCode.eur:
        return 'Euros';
    }
  }

  Locale get locale {
    switch (this) {
      case CurrencyCode.pen:
        return const Locale('es', 'PE');
      case CurrencyCode.usd:
        return const Locale('en', 'US');
      case CurrencyCode.eur:
        return const Locale('de', 'DE');
    }
  }
}

class CurrencyRates {
  static const Map<CurrencyCode, double> _ratesFromPEN = {
    CurrencyCode.pen: 1.0,
    CurrencyCode.usd: 0.27,
    CurrencyCode.eur: 0.25,
  };

  static double convert(double amount, CurrencyCode from, CurrencyCode to) {
    if (from == to) return amount;
    
    final amountInPEN = amount / _ratesFromPEN[from]!;
    return amountInPEN * _ratesFromPEN[to]!;
  }
}

class CurrencyPreferenceNotifier extends StateNotifier<CurrencyCode> {
  static const String _key = 'user_currency Preference';
  final SharedPreferences _prefs;

  CurrencyPreferenceNotifier(this._prefs) : super(CurrencyCode.pen) {
    _load();
  }

  void _load() {
    final saved = _prefs.getString(_key);
    if (saved != null) {
      state = CurrencyCode.values.firstWhere(
        (c) => c.code == saved,
        orElse: () => CurrencyCode.pen,
      );
    }
  }

  Future<void> setCurrency(CurrencyCode currency) async {
    await _prefs.setString(_key, currency.code);
    state = currency;
  }
}

final currencyPreferenceProvider = StateNotifierProvider<CurrencyPreferenceNotifier, CurrencyCode>((ref) {
  throw UnimplementedError('Debe ser sobreescrito en bootstrap');
});

String formatCurrency(double amount, CurrencyCode currency) {
  final formatted = amount.toStringAsFixed(2);
  return '${currency.symbol}$formatted';
}

double getExchangeRate(CurrencyCode from, CurrencyCode to) {
  return CurrencyRates.convert(1.0, from, to);
}