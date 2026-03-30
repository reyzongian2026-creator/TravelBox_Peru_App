import 'dart:typed_data';

class SelectedEvidenceImage {
  const SelectedEvidenceImage({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });

  final String filename;
  final String mimeType;
  final Uint8List bytes;

  int get sizeBytes => bytes.length;
}
