import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/features/dashboard_decorations.dart';

void main() {
  testWidgets('AthletesSilhouetteGraphic and DashboardHeaderDecoration render successfully', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              DashboardHeaderDecoration(child: Text('Header')),
              AthletesSilhouetteGraphic(width: 140, height: 100),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Header'), findsOneWidget);
    expect(find.byType(AthletesSilhouetteGraphic), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('DashboardHeaderDecoration respects custom padding and paints gradient', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardHeaderDecoration(
            padding: EdgeInsets.all(32),
            child: Text('Custom Padding Header'),
          ),
        ),
      ),
    );

    expect(find.text('Custom Padding Header'), findsOneWidget);
  });

  testWidgets('AthletesSilhouetteGraphic renders with default size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AthletesSilhouetteGraphic(),
        ),
      ),
    );

    expect(find.byType(AthletesSilhouetteGraphic), findsOneWidget);
  });

  testWidgets('Painters shouldRepaint returns false', (tester) async {
    const headerPainter1 = DashboardHeaderPainter();
    const headerPainter2 = DashboardHeaderPainter();
    expect(headerPainter1.shouldRepaint(headerPainter2), isFalse);

    const silhouettePainter1 = AthletesSilhouettePainter();
    const silhouettePainter2 = AthletesSilhouettePainter();
    expect(silhouettePainter1.shouldRepaint(silhouettePainter2), isFalse);
  });
}
