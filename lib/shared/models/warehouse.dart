class Warehouse {
  const Warehouse({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.district,
    required this.latitude,
    required this.longitude,
    required this.openingHours,
    required this.priceFromPerHour,
    required this.pricePerHourSmall,
    required this.pricePerHourMedium,
    required this.pricePerHourLarge,
    required this.pricePerHourExtraLarge,
    required this.pickupFee,
    required this.dropoffFee,
    required this.insuranceFee,
    required this.score,
    required this.availableSlots,
    required this.extraServices,
    this.currencyCode = 'PEN',
    this.imageUrl,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String district;
  final double latitude;
  final double longitude;
  final String openingHours;
  final double priceFromPerHour;
  final double pricePerHourSmall;
  final double pricePerHourMedium;
  final double pricePerHourLarge;
  final double pricePerHourExtraLarge;
  final double pickupFee;
  final double dropoffFee;
  final double insuranceFee;
  final double score;
  final int availableSlots;
  final List<String> extraServices;
  final String currencyCode;
  final String? imageUrl;

  double rateForSize(String rawSize) {
    switch (rawSize.trim().toUpperCase()) {
      case 'S':
        return pricePerHourSmall;
      case 'L':
        return pricePerHourLarge;
      case 'XL':
        return pricePerHourExtraLarge;
      case 'M':
      default:
        return pricePerHourMedium;
    }
  }

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    final openHour = json['openHour']?.toString();
    final closeHour = json['closeHour']?.toString();
    final openingHours = (openHour != null && closeHour != null)
        ? '$openHour - $closeHour'
        : json['openingHours']?.toString();
    final available =
        (json['availableSlots'] as num?)?.toInt() ??
        (json['availableInRange'] as num?)?.toInt() ??
        (json['available'] as num?)?.toInt();
    final capacity = (json['capacity'] as num?)?.toInt() ?? 0;
    final occupied = (json['occupied'] as num?)?.toInt() ?? 0;
    final mediumRate =
        (json['pricePerHourMedium'] as num?)?.toDouble() ??
        (json['priceFromPerHour'] as num?)?.toDouble() ??
        (json['hourlyRate'] as num?)?.toDouble() ??
        (json['pricePerHour'] as num?)?.toDouble() ??
        4.5;

    return Warehouse(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? json['cityName']?.toString() ?? '',
      district:
          json['district']?.toString() ?? json['zoneName']?.toString() ?? '',
      latitude:
          (json['latitude'] as num?)?.toDouble() ??
          (json['lat'] as num?)?.toDouble() ??
          0,
      longitude:
          (json['longitude'] as num?)?.toDouble() ??
          (json['lng'] as num?)?.toDouble() ??
          0,
      openingHours: openingHours ?? '08:00 - 22:00',
      priceFromPerHour: mediumRate,
      pricePerHourSmall:
          (json['pricePerHourSmall'] as num?)?.toDouble() ?? mediumRate,
      pricePerHourMedium: mediumRate,
      pricePerHourLarge:
          (json['pricePerHourLarge'] as num?)?.toDouble() ?? mediumRate,
      pricePerHourExtraLarge:
          (json['pricePerHourExtraLarge'] as num?)?.toDouble() ?? mediumRate,
      pickupFee:
          (json['pickupFee'] as num?)?.toDouble() ??
          (json['pickupDeliveryFee'] as num?)?.toDouble() ??
          14,
      dropoffFee:
          (json['dropoffFee'] as num?)?.toDouble() ??
          (json['dropoffDeliveryFee'] as num?)?.toDouble() ??
          14,
      insuranceFee: (json['insuranceFee'] as num?)?.toDouble() ?? 7.5,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      availableSlots: available ?? (capacity > 0 ? capacity - occupied : 0),
      extraServices: _parseExtraServices(json),
      currencyCode: _readCurrencyCode(json),
      imageUrl: _readImageUrl(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'district': district,
      'latitude': latitude,
      'longitude': longitude,
      'openingHours': openingHours,
      'priceFromPerHour': priceFromPerHour,
      'pricePerHourSmall': pricePerHourSmall,
      'pricePerHourMedium': pricePerHourMedium,
      'pricePerHourLarge': pricePerHourLarge,
      'pricePerHourExtraLarge': pricePerHourExtraLarge,
      'pickupFee': pickupFee,
      'dropoffFee': dropoffFee,
      'insuranceFee': insuranceFee,
      'score': score,
      'availableSlots': availableSlots,
      'extraServices': extraServices,
      'currencyCode': currencyCode,
      'imageUrl': imageUrl,
    };
  }
}

List<String> _parseExtraServices(Map<String, dynamic> json) {
  final extras = (json['extraServices'] as List<dynamic>? ?? [])
      .map((e) => e.toString())
      .where((e) => e.trim().isNotEmpty)
      .toList();
  if (extras.isNotEmpty) {
    return extras;
  }
  final rules = json['rules']?.toString();
  if (rules == null || rules.trim().isEmpty) {
    return const [];
  }
  return [rules.trim()];
}

String? _readImageUrl(Map<String, dynamic> json) {
  const keys = [
    'coverImageUrl',
    'imageUrl',
    'photoUrl',
    'image',
    'imagen',
    'url',
  ];
  for (final key in keys) {
    final value = json[key]?.toString();
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

String _readCurrencyCode(Map<String, dynamic> json) {
  const keys = ['currencyCode', 'currency', 'moneda', 'currency_code'];
  for (final key in keys) {
    final value = json[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value.toUpperCase();
    }
  }
  return 'PEN';
}
