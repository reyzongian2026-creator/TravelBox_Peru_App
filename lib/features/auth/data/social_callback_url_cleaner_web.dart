// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<void> clearSocialCallbackUrl({required String route}) async {
  final trimmed = route.trim();
  final normalized = trimmed.isEmpty
      ? '/login'
      : (trimmed.startsWith('/') ? trimmed : '/$trimmed');
  html.window.history.replaceState(
    null,
    html.document.title,
    '/#$normalized',
  );
}
