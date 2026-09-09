import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/features/login_decorations.dart';

void main() {
  testWidgets(
    'LoginHeaderDecoration renders child with CustomPaint background',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginHeaderDecoration(child: Text('Header Content')),
          ),
        ),
      );

      expect(find.text('Header Content'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    },
  );

  testWidgets('LoginHeaderPainter shouldRepaint returns false', (tester) async {
    const painter1 = LoginHeaderPainter();
    const painter2 = LoginHeaderPainter();
    expect(painter1.shouldRepaint(painter2), isFalse);
  });
}
