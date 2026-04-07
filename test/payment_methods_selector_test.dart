import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelbox_peru_app/core/l10n/app_localizations_fixed.dart';
import 'package:travelbox_peru_app/features/payments/presentation/widgets/payment_methods_selector.dart';

void main() {
  testWidgets('PaymentMethodsSelector emits callback when selecting a method', (
    tester,
  ) async {
    PaymentMethodType? selected;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PaymentMethodsSelector(
            initialSelected: PaymentMethodType.yape,
            onMethodSelected: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GestureDetector), findsWidgets);

    await tester.tap(find.byType(GestureDetector).at(1));
    await tester.pumpAndSettle();

    expect(selected, PaymentMethodType.plin);
  });
}
