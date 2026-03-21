import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelbox_peru_app/core/l10n/app_localizations.dart';
import 'package:travelbox_peru_app/features/auth/presentation/auth_portal_page.dart';

Finder textContainsAny(List<String> snippets) {
  final normalized = snippets.map((s) => s.toLowerCase()).toList();
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final data = (widget.data ?? '').toLowerCase();
    return normalized.any(data.contains);
  });
}

void main() {
  testWidgets('Auth portal page loads and displays form elements', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthPortalPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Form), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(TextButton), findsWidgets);
  });
}
