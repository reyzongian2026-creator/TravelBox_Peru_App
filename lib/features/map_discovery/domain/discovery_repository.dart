import '../../../shared/models/warehouse.dart';

abstract class DiscoveryRepository {
  Future<List<Warehouse>> searchWarehouses({
    String? query,
    double? latitude,
    double? longitude,
    String? baggageSize,
  });

  Future<Warehouse?> getWarehouseById(String warehouseId);
}
