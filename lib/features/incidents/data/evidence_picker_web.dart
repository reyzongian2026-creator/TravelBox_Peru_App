// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'selected_evidence_image.dart';

const _maxImageDimension = 1280;
const _compressIfLargerThanBytes = 1400 * 1024;

Future<SelectedEvidenceImage?> pickEvidenceImage() {
  final completer = Completer<SelectedEvidenceImage?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg,image/webp';

  input.onChange.first.then((_) async {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return;
    }
    try {
      final normalized = await _normalizeSelectedImage(file);
      if (!completer.isCompleted) {
        completer.complete(normalized);
      }
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
  });

  input.click();
  return completer.future;
}

Future<SelectedEvidenceImage> _normalizeSelectedImage(html.File file) async {
  if (file.size <= _compressIfLargerThanBytes) {
    return _readFile(file);
  }

  final objectUrl = html.Url.createObjectUrl(file);
  try {
    final image = html.ImageElement(src: objectUrl);
    await image.onLoad.first.timeout(const Duration(seconds: 10));

    final width = image.naturalWidth;
    final height = image.naturalHeight;
    if (width <= 0 || height <= 0) {
      return _readFile(file);
    }

    final scale = width > height
        ? _maxImageDimension / width
        : _maxImageDimension / height;
    final targetWidth = scale < 1 ? (width * scale).round() : width;
    final targetHeight = scale < 1 ? (height * scale).round() : height;

    final canvas = html.CanvasElement(
      width: targetWidth,
      height: targetHeight,
    );
    final context = canvas.context2D;
    context.imageSmoothingEnabled = true;
    context.drawImageScaled(image, 0, 0, targetWidth, targetHeight);

    final blob = await _canvasToBlob(canvas);
    if (blob == null) {
      return _readFile(file);
    }

    final compressed = await _readBlob(
      blob,
      _normalizedJpegFileName(file.name),
      'image/jpeg',
    );
    if (compressed.sizeBytes >= file.size) {
      return _readFile(file);
    }
    return compressed;
  } catch (_) {
    return _readFile(file);
  } finally {
    html.Url.revokeObjectUrl(objectUrl);
  }
}

Future<html.Blob?> _canvasToBlob(html.CanvasElement canvas) {
  return canvas.toBlob('image/jpeg');
}

Future<SelectedEvidenceImage> _readFile(html.File file) async {
  return _readBlob(
    file,
    file.name,
    file.type.isNotEmpty ? file.type : _mimeTypeFromName(file.name),
  );
}

Future<SelectedEvidenceImage> _readBlob(
  html.Blob blob,
  String filename,
  String mimeType,
) async {
  final reader = html.FileReader();
  final completer = Completer<SelectedEvidenceImage>();
  reader.onError.first.then((_) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('No se pudo leer la imagen.'));
    }
  });
  reader.onLoadEnd.first.then((_) {
    if (completer.isCompleted) return;
    final result = reader.result;
    if (result is! ByteBuffer) {
      completer.completeError(StateError('Formato de imagen invalido.'));
      return;
    }
    completer.complete(
      SelectedEvidenceImage(
        filename: filename,
        mimeType: mimeType,
        bytes: Uint8List.view(result),
      ),
    );
  });
  reader.readAsArrayBuffer(blob);
  return completer.future;
}

String _normalizedJpegFileName(String originalName) {
  final dotIndex = originalName.lastIndexOf('.');
  final baseName = dotIndex > 0 ? originalName.substring(0, dotIndex) : originalName;
  return '$baseName.jpg';
}

String _mimeTypeFromName(String filename) {
  final normalized = filename.toLowerCase();
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (normalized.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/png';
}
