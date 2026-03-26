import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations_fixed.dart';
import '../state/session_controller.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  static const _languages = [
    _LanguageInfo(code: 'es', flag: 'ES'),
    _LanguageInfo(code: 'en', flag: 'EN'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final currentLanguage = session.sessionLanguage;
    final l10n = context.l10n;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      tooltip: l10n.t('change_language'),
      onSelected: (String languageCode) {
        ref
            .read(sessionControllerProvider.notifier)
            .setSessionLanguage(languageCode);
      },
      itemBuilder: (BuildContext context) {
        return _languages.map((lang) {
          final isSelected = lang.code == currentLanguage;
          return PopupMenuItem<String>(
            value: lang.code,
            child: Row(
              children: [
                Text(
                  lang.flag,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.label(l10n),
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check,
                    color: Theme.of(context).primaryColor,
                    size: 18,
                  ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

class _LanguageInfo {
  final String code;
  final String flag;

  const _LanguageInfo({
    required this.code,
    required this.flag,
  });

  String label(AppLocalizations l10n) {
    return switch (code) {
      'es' => l10n.t('spanish'),
      'en' => l10n.t('english'),
      _ => code.toUpperCase(),
    };
  }
}

Future<void> showLanguageSelectorDialog(BuildContext context) async {
  final selectedLanguage = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.language),
            const SizedBox(width: 8),
            Text(l10n.t('change_language')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LanguageSelector._languages.map((lang) {
            return ListTile(
              leading: Text(
                lang.flag,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              title: Text(lang.label(l10n)),
              onTap: () {
                Navigator.of(dialogContext).pop(lang.code);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.t('close')),
          ),
        ],
      );
    },
  );

  if (!context.mounted || selectedLanguage == null) {
    return;
  }

  ProviderScope.containerOf(
    context,
  ).read(sessionControllerProvider.notifier).setSessionLanguage(selectedLanguage);
}
