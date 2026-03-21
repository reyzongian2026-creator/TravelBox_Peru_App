class Rating {
  final int? id;
  final int warehouseId;
  final String? warehouseName;
  final int? reservationId;
  final int stars;
  final String? comment;
  final String? userName;
  final String? userAvatar;
  final DateTime? createdAt;
  final bool verified;
  final String? type;

  Rating({
    this.id,
    required this.warehouseId,
    this.warehouseName,
    this.reservationId,
    required this.stars,
    this.comment,
    this.userName,
    this.userAvatar,
    this.createdAt,
    this.verified = false,
    this.type,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'] as int?,
      warehouseId: json['warehouseId'] as int,
      warehouseName: json['warehouseName'] as String?,
      reservationId: json['reservationId'] as int?,
      stars: json['stars'] as int,
      comment: json['comment'] as String?,
      userName: json['userName'] as String?,
      userAvatar: json['userAvatar'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      verified: json['verified'] as bool? ?? false,
      type: json['type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'warehouseId': warehouseId,
      if (reservationId != null) 'reservationId': reservationId,
      'stars': stars,
      if (comment != null) 'comment': comment,
      if (type != null) 'type': type,
    };
  }
}

class WarehouseRatingSummary {
  final int warehouseId;
  final String warehouseName;
  final double averageStars;
  final int totalRatings;
  final int stars1Count;
  final int stars2Count;
  final int stars3Count;
  final int stars4Count;
  final int stars5Count;

  WarehouseRatingSummary({
    required this.warehouseId,
    required this.warehouseName,
    required this.averageStars,
    required this.totalRatings,
    this.stars1Count = 0,
    this.stars2Count = 0,
    this.stars3Count = 0,
    this.stars4Count = 0,
    this.stars5Count = 0,
  });

  factory WarehouseRatingSummary.fromJson(Map<String, dynamic> json) {
    return WarehouseRatingSummary(
      warehouseId: json['warehouseId'] as int,
      warehouseName: json['warehouseName'] as String,
      averageStars: (json['averageStars'] as num).toDouble(),
      totalRatings: json['totalRatings'] as int,
      stars1Count: json['stars1Count'] as int? ?? 0,
      stars2Count: json['stars2Count'] as int? ?? 0,
      stars3Count: json['stars3Count'] as int? ?? 0,
      stars4Count: json['stars4Count'] as int? ?? 0,
      stars5Count: json['stars5Count'] as int? ?? 0,
    );
  }

  double get percentage5 => totalRatings > 0 ? (stars5Count / totalRatings) * 100 : 0;
  double get percentage4 => totalRatings > 0 ? (stars4Count / totalRatings) * 100 : 0;
  double get percentage3 => totalRatings > 0 ? (stars3Count / totalRatings) * 100 : 0;
  double get percentage2 => totalRatings > 0 ? (stars2Count / totalRatings) * 100 : 0;
  double get percentage1 => totalRatings > 0 ? (stars1Count / totalRatings) * 100 : 0;
}
