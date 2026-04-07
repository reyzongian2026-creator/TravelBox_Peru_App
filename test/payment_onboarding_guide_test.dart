import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelbox_peru_app/shared/widgets/payment_onboarding_guide.dart';

void main() {
  testWidgets(
    'PaymentOnboardingGuide expands and shows method-specific steps',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PaymentOnboardingGuide(method: 'plin')),
        ),
      );

      expect(find.text('Como funciona?'), findsOneWidget);

      await tester.tap(find.text('Como funciona?'));
      await tester.pumpAndSettle();

      expect(find.text('Transfiere desde tu app Plin'), findsOneWidget);
      expect(find.text('Espera la confirmacion'), findsOneWidget);
    },
  );
}
