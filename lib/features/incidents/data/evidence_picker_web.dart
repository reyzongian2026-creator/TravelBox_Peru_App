// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'selected_evidence_image.dart';

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
      final selected = await _readFile(file);
      if (!completer.isCompleted) {
        completer.complete(selected);
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
