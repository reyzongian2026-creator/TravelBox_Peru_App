import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelbox_peru_app/shared/widgets/travelbox_logo.dart';

void main() {
  testWidgets('TravelBoxLogo stays stable on very narrow width', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 96, child: TravelBoxLogo(compact: true)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));

    expect(tester.takeException(), isNull);
    expect(find.byType(TravelBoxLogo), findsOneWidget);
  });
}
