import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Increments whenever warehouses are created, edited or deleted.
/// Pages that show warehouse data can watch this provider to auto-refresh.
final warehouseCatalogVersionProvider = StateProvider<int>((ref) => 0);
