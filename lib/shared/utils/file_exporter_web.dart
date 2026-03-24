// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

const bool fileExportSupported = true;

Future<bool> downloadTextFile({
  required String filename,
  required String content,
  required String mimeType,
}) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}

Future<bool> downloadFromUrl(String downloadUrl, String filename) async {
  final anchor = html.AnchorElement(href: downloadUrl)
    ..download = filename
    ..target = '_blank'
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  return true;
}

Future<bool> openPrintPreview({
  required String title,
  required String htmlContent,
}) async {
  final document =
      '''
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8">
    <title>${htmlEscape.convert(title)}</title>
    <style>
      body { font-family: Arial, sans-serif; margin: 24px; color: #111827; }
      h1 { font-size: 22px; margin-bottom: 8px; }
      p { margin: 0 0 12px; }
      table { width: 100%; border-collapse: collapse; margin-top: 16px; }
      th, td { border: 1px solid #D1D5DB; padding: 8px; font-size: 12px; text-align: left; vertical-align: top; }
      th { background: #F3F4F6; }
      .meta { color: #4B5563; font-size: 12px; }
      @media print {
        body { margin: 12px; }
      }
    </style>
  </head>
  <body onload="setTimeout(function(){ window.print(); }, 250);">
    $htmlContent
  </body>
</html>
''';

  final uri = 'data:text/html;charset=utf-8,${Uri.encodeComponent(document)}';
  html.window.open(uri, '_blank');
  return true;
}
