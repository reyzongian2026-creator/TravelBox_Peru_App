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
  testWidgets('Auth portal toggles between internal and client access modes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AuthPortalPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(textContainsAny(['interno', 'internal']), findsWidgets);
    expect(
      textContainsAny(['acceso personal interno', 'internal staff access']),
      findsOneWidget,
    );
    expect(
      textContainsAny([
        'ingresar personal interno',
        'sign in as internal staff',
      ]),
      findsOneWidget,
    );

    await tester.tap(textContainsAny(['cliente', 'client']).first);
    await tester.pump(const Duration(milliseconds: 450));

    expect(
      textContainsAny(['acceso cliente', 'client access']),
      findsOneWidget,
    );
    expect(
      textContainsAny(['ingresar como cliente', 'sign in as client']),
      findsOneWidget,
    );
    expect(
      textContainsAny(['crear cuenta cliente', 'create client account']),
      findsOneWidget,
    );
    expect(find.textContaining('Google'), findsOneWidget);
    expect(find.textContaining('Facebook'), findsOneWidget);
  });
}
