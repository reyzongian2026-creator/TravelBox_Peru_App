import 'dart:typed_data';
import 'dart:ui' as ui;

Future<String?> validateSelectedImageForUpload({
  required Uint8List bytes,
  required String Function(String key) t,
  int minBytes = 5 * 1024,
  int minWidth = 50,
  int minHeight = 50,
}) async {
  if (bytes.length < minBytes) {
    return t('image_upload_min_size');
  }

  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final isTooSmall = image.width < minWidth || image.height < minHeight;
    image.dispose();
    codec.dispose();

    if (isTooSmall) {
      return t('image_upload_min_dimensions');
    }
    return null;
  } catch (_) {
    return t('image_upload_invalid');
  }
}
