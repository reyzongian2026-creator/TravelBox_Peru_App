import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session_controller.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  static const _languages = [
    _LanguageInfo(code: 'es', name: 'Español', flag: '🇪🇸'),
    _LanguageInfo(code: 'en', name: 'English', flag: '🇬🇧'),
    _LanguageInfo(code: 'de', name: 'Deutsch', flag: '🇩🇪'),
    _LanguageInfo(code: 'fr', name: 'Français', flag: '🇫🇷'),
    _LanguageInfo(code: 'it', name: 'Italiano', flag: '🇮🇹'),
    _LanguageInfo(code: 'pt', name: 'Português', flag: '🇧🇷'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final currentLanguage = session.sessionLanguage;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      tooltip: 'Cambiar idioma',
      onSelected: (String languageCode) {
        ref.read(sessionControllerProvider.notifier).setSessionLanguage(languageCode);
      },
      itemBuilder: (BuildContext context) {
        return _languages.map((lang) {
          final isSelected = lang.code == currentLanguage;
          return PopupMenuItem<String>(
            value: lang.code,
            child: Row(
              children: [
                Text(lang.flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
  final String name;
  final String flag;

  const _LanguageInfo({
    required this.code,
    required this.name,
    required this.flag,
  });
}

Future<void> showLanguageSelectorDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.language),
          SizedBox(width: 8),
          Text('Cambiar idioma'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: LanguageSelector._languages.map((lang) {
          return ListTile(
            leading: Text(lang.flag, style: const TextStyle(fontSize: 24)),
            title: Text(lang.name),
            onTap: () {
              Navigator.of(context).pop();
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
