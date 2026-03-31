import 'package:file_picker/file_picker.dart';

import 'selected_evidence_image.dart';

Future<SelectedEvidenceImage?> pickEvidenceImage() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );
  final file = result != null && result.files.isNotEmpty
      ? result.files.first
      : null;
  if (file == null || file.bytes == null) {
    return null;
  }
  return SelectedEvidenceImage(
    filename: file.name,
    mimeType: _mimeTypeFromName(file.extension ?? file.name),
    bytes: file.bytes!,
  );
}

String _mimeTypeFromName(String filenameOrExtension) {
  final normalized = filenameOrExtension.toLowerCase();
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (normalized.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/png';
}
