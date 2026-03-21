// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'selected_evidence_image.dart';

Future<SelectedEvidenceImage?> pickEvidenceImage() {
  final completer = Completer<SelectedEvidenceImage?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg,image/webp';

  input.onChange.first.then((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return;
    }

    final reader = html.FileReader();
    reader.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
    reader.onLoadEnd.first.then((_) {
      if (completer.isCompleted) return;
      final result = reader.result;
      if (result is! ByteBuffer) {
        completer.complete(null);
        return;
      }
      completer.complete(
        SelectedEvidenceImage(
          filename: file.name,
          mimeType: file.type.isNotEmpty
              ? file.type
              : _mimeTypeFromName(file.name),
          bytes: Uint8List.view(result),
        ),
      );
    });
    reader.readAsArrayBuffer(file);
  });

  input.click();
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
