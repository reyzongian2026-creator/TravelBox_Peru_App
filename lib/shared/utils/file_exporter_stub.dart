const bool fileExportSupported = false;

Future<bool> downloadTextFile({
  required String filename,
  required String content,
  required String mimeType,
}) async {
  return false;
}

Future<bool> openPrintPreview({
  required String title,
  required String htmlContent,
}) async {
  return false;
}
