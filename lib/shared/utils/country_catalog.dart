import '../../core/l10n/localization_runtime.dart';

class CountryDialingInfo {
  const CountryDialingInfo({
    required this.countryName,
    required this.iso2,
    required this.dialCode,
    required this.phoneMinDigits,
    required this.phoneMaxDigits,
    required this.defaultLanguage,
    required this.phoneHint,
  });

  final String countryName;
  final String iso2;
  final String dialCode;
  final int phoneMinDigits;
  final int phoneMaxDigits;
  final String defaultLanguage;
  final String phoneHint;
}

const countryDialingCatalog = <CountryDialingInfo>[
  CountryDialingInfo(
    countryName: 'Peru',
    iso2: 'PE',
    dialCode: '+51',
    phoneMinDigits: 9,
    phoneMaxDigits: 9,
    defaultLanguage: 'es',
    phoneHint: '999888777',
  ),
  CountryDialingInfo(
    countryName: 'Germany',
    iso2: 'DE',
    dialCode: '+49',
    phoneMinDigits: 10,
    phoneMaxDigits: 11,
    defaultLanguage: 'de',
    phoneHint: '15123456789',
  ),
  CountryDialingInfo(
    countryName: 'Spain',
    iso2: 'ES',
    dialCode: '+34',
    phoneMinDigits: 9,
    phoneMaxDigits: 9,
    defaultLanguage: 'es',
    phoneHint: '612345678',
  ),
  CountryDialingInfo(
    countryName: 'United States',
    iso2: 'US',
    dialCode: '+1',
    phoneMinDigits: 10,
    phoneMaxDigits: 10,
    defaultLanguage: 'en',
    phoneHint: '4155551234',
  ),
  CountryDialingInfo(
    countryName: 'United Kingdom',
    iso2: 'GB',
    dialCode: '+44',
    phoneMinDigits: 10,
    phoneMaxDigits: 10,
    defaultLanguage: 'en',
    phoneHint: '7700900123',
  ),
  CountryDialingInfo(
    countryName: 'France',
    iso2: 'FR',
    dialCode: '+33',
    phoneMinDigits: 9,
    phoneMaxDigits: 9,
    defaultLanguage: 'fr',
    phoneHint: '612345678',
  ),
  CountryDialingInfo(
    countryName: 'Italy',
    iso2: 'IT',
    dialCode: '+39',
    phoneMinDigits: 9,
    phoneMaxDigits: 10,
    defaultLanguage: 'it',
    phoneHint: '3123456789',
  ),
  CountryDialingInfo(
    countryName: 'Brazil',
    iso2: 'BR',
    dialCode: '+55',
    phoneMinDigits: 10,
    phoneMaxDigits: 11,
    defaultLanguage: 'pt',
    phoneHint: '11987654321',
  ),
  CountryDialingInfo(
    countryName: 'Chile',
    iso2: 'CL',
    dialCode: '+56',
    phoneMinDigits: 9,
    phoneMaxDigits: 9,
    defaultLanguage: 'es',
    phoneHint: '912345678',
  ),
  CountryDialingInfo(
    countryName: 'Colombia',
    iso2: 'CO',
    dialCode: '+57',
    phoneMinDigits: 10,
    phoneMaxDigits: 10,
    defaultLanguage: 'es',
    phoneHint: '3001234567',
  ),
  CountryDialingInfo(
    countryName: 'Mexico',
    iso2: 'MX',
    dialCode: '+52',
    phoneMinDigits: 10,
    phoneMaxDigits: 10,
    defaultLanguage: 'es',
    phoneHint: '5512345678',
  ),
  CountryDialingInfo(
    countryName: 'Argentina',
    iso2: 'AR',
    dialCode: '+54',
    phoneMinDigits: 10,
    phoneMaxDigits: 10,
    defaultLanguage: 'es',
    phoneHint: '91123456789',
  ),
  CountryDialingInfo(
    countryName: 'Japan',
    iso2: 'JP',
    dialCode: '+81',
    phoneMinDigits: 10,
    phoneMaxDigits: 11,
    defaultLanguage: 'en',
    phoneHint: '9012345678',
  ),
];

CountryDialingInfo resolveCountryDialingByName(String? countryName) {
  final normalized = _normalizeCountryName(countryName);
  for (final item in countryDialingCatalog) {
    if (_normalizeCountryName(item.countryName) == normalized) {
      return item;
    }
  }
  return countryDialingCatalog.first;
}

CountryDialingInfo resolveCountryDialingByPhone(String? phone) {
  final value = phone?.trim() ?? '';
  for (final item in countryDialingCatalog) {
    if (value.startsWith(item.dialCode)) {
      return item;
    }
  }
  return countryDialingCatalog.first;
}

String normalizeInternationalPhone({
  required CountryDialingInfo country,
  required String localNumber,
}) {
  final digits = localNumber.replaceAll(RegExp(r'\D'), '');
  return '${country.dialCode}$digits';
}

String extractLocalNumber({
  required CountryDialingInfo country,
  required String rawPhone,
}) {
  final trimmed = rawPhone.trim();
  if (!trimmed.startsWith(country.dialCode)) {
    return trimmed.replaceAll(RegExp(r'\D'), '');
  }
  return trimmed
      .substring(country.dialCode.length)
      .replaceAll(RegExp(r'\D'), '');
}

String? validateInternationalPhone({
  required CountryDialingInfo country,
  required String localNumber,
  String label = 'un telefono valido',
}) {
  final digits = localNumber.replaceAll(RegExp(r'\D'), '');
  if (digits.length < country.phoneMinDigits ||
      digits.length > country.phoneMaxDigits) {
    if (LocalizationRuntime.isSpanish) {
      return 'Ingresa un telefono valido para ${country.countryName} '
          '(${country.dialCode}).';
    }
    return 'Enter a valid phone number for ${country.countryName} '
        '(${country.dialCode}).';
  }
  return null;
}

String _normalizeCountryName(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  return switch (value) {
    'alemania' => 'germany',
    'espana' => 'spain',
    'españa' => 'spain',
    'estados unidos' => 'united states',
    'reino unido' => 'united kingdom',
    'francia' => 'france',
    'italia' => 'italy',
    'brasil' => 'brazil',
    'japon' => 'japan',
    'japón' => 'japan',
    _ => value,
  };
}
