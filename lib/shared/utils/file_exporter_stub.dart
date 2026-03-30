const bool fileExportSupported = false;

Future<bool> downloadBinaryFile({
  required String filename,
  required List<int> bytes,
  required String mimeType,
}) async {
  return false;
}

Future<bool> downloadTextFile({
  required String filename,
  required String content,
  required String mimeType,
}) async {
  return false;
}

Future<bool> downloadFromUrl(String downloadUrl, String filename) async {
  return false;
}

Future<bool> openPrintPreview({
  required String title,
  required String htmlContent,
}) async {
  return false;
}
