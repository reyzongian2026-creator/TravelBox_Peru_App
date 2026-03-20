import 'dart:io';

const _criticalFiles = <String>[
  'lib/core/router/app_router.dart',
  'lib/features/auth/presentation/auth_portal_page.dart',
  'lib/features/auth/presentation/password_reset_page.dart',
  'lib/features/auth/presentation/register_page.dart',
  'lib/features/delivery/presentation/delivery_request_page.dart',
  'lib/features/qr_scan/presentation/qr_scan_page.dart',
  'lib/features/reservation/presentation/reservation_detail_page.dart',
];

final _uiLiteralPatterns = <RegExp>[
  RegExp(r"\bText\(\s*'[^']+'"),
  RegExp(r"labelText:\s*'[^']+'"),
  RegExp(r"hintText:\s*'[^']+'"),
  RegExp(r"tooltip:\s*'[^']+'"),
  RegExp(r"SnackBar\(content:\s*Text\(\s*'[^']+'"),
];

void main() {
  final findings = <String>[];

  for (final filePath in _criticalFiles) {
    final file = File(filePath);
    if (!file.existsSync()) {
      findings.add('$filePath:0 missing critical file');
      continue;
    }

    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLocalizedLine =
          line.contains("l10n.t('") || line.contains('l10n.t("');
      if (isLocalizedLine) {
        continue;
      }

      for (final pattern in _uiLiteralPatterns) {
        if (pattern.hasMatch(line)) {
          findings.add('$filePath:${i + 1} hardcoded-ui-string');
          break;
        }
      }
    }
  }

  final l10nFile = File('lib/core/l10n/app_localizations.dart');
  if (!l10nFile.existsSync()) {
    findings.add(
      'lib/core/l10n/app_localizations.dart:0 missing localization file',
    );
  } else {
    final content = l10nFile.readAsStringSync();
    final priorityStart = content.indexOf('_priorityTranslations');
    if (priorityStart >= 0) {
      final translationsStart = content.indexOf('_translations', priorityStart);
      final prioritySlice = translationsStart > priorityStart
          ? content.substring(priorityStart, translationsStart)
          : content.substring(priorityStart);
      final placeholderInPriority = RegExp(
        ":\\s*['\\\"][^'\\\"]*\\([A-Z]{2,4}\\)\\s*['\\\"]",
      ).hasMatch(prioritySlice);
      if (placeholderInPriority) {
        findings.add(
          'lib/core/l10n/app_localizations.dart:0 placeholder values found in priority translations',
        );
      }
    }
  }

  if (findings.isEmpty) {
    stdout.writeln('mobile_quality_guard: OK');
    return;
  }

  stderr.writeln('mobile_quality_guard: FAIL');
  for (final finding in findings) {
    stderr.writeln(' - $finding');
  }
  exitCode = 1;
}
