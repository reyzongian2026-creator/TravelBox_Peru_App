import '../../core/env/app_env.dart';

class AppMapTiles {
  static String get rasterUrlTemplate {
    final azureKey = AppEnv.azureMapsApiKey.trim();
    if (azureKey.isEmpty) {
      // Carto Voyager: free raster tiles that work on web (no User-Agent header needed)
      return 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
    }

    // `microsoft.base` returns vector tiles. Flutter map widgets need raster
    // image tiles, so we force the Azure Maps raster tileset everywhere.
    return 'https://atlas.microsoft.com/map/tile?api-version=2024-04-01&tilesetId=microsoft.base.road&zoom={z}&x={x}&y={y}&tileSize=256&language=es-ES&view=Auto&subscription-key=$azureKey';
  }
}
