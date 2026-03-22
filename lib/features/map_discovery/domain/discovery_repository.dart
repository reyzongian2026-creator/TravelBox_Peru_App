import '../../../shared/models/warehouse.dart';

abstract class DiscoveryRepository {
  Future<List<Warehouse>> searchWarehouses({
    String? query,
    double? latitude,
    double? longitude,
    String? baggageSize,
  });

  Future<Warehouse?> getWarehouseById(String warehouseId);

  Future<String?> getWarehouseImage(String warehouseId);

  Future<List<Warehouse>> findNearbyWarehouses({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    String? baggageSize,
  });

  Future<WarehouseAvailabilityResult> searchAvailability({
    double? latitude,
    double? longitude,
    DateTime? startAt,
    DateTime? endAt,
    int? baggageCount,
    String? baggageSize,
  });
}

class WarehouseAvailabilityResult {
  final bool hasAvailability;
  final List<Warehouse> warehouses;
  final int totalCount;

  const WarehouseAvailabilityResult({
    required this.hasAvailability,
    required this.warehouses,
    required this.totalCount,
  });
}
