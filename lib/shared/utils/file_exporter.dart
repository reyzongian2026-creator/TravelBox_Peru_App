import 'file_exporter_stub.dart'
    if (dart.library.html) 'file_exporter_web.dart'
    as impl;

bool get fileExportSupported => impl.fileExportSupported;

Future<bool> downloadBinaryFile({
  required String filename,
  required List<int> bytes,
  required String mimeType,
}) {
  return impl.downloadBinaryFile(
    filename: filename,
    bytes: bytes,
    mimeType: mimeType,
  );
}

Future<bool> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/plain;charset=utf-8',
}) {
  return impl.downloadTextFile(
    filename: filename,
    content: content,
    mimeType: mimeType,
  );
}

Future<bool> downloadFromUrl(String downloadUrl, String filename) {
  return impl.downloadFromUrl(downloadUrl, filename);
}

Future<bool> openPrintPreview({
  required String title,
  required String htmlContent,
}) {
  return impl.openPrintPreview(title: title, htmlContent: htmlContent);
}
