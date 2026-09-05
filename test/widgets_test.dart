import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/theme.dart';
import 'package:kok_app/shared/widgets.dart';

void main() {
  group('DashedDivider', () {
    testWidgets('renders with default values', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashedDivider(),
          ),
        ),
      );

      final dividerFinder = find.byType(DashedDivider);
      expect(dividerFinder, findsOneWidget);

      final divider = tester.widget<DashedDivider>(dividerFinder);
      expect(divider.height, 1.0);
      expect(divider.dashWidth, 5.0);
      expect(divider.dashSpace, 3.0);
      expect(divider.color, const Color(0xFFE5E7EB));

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders with custom configuration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashedDivider(
              height: 2.5,
              dashWidth: 8.0,
              dashSpace: 4.0,
              color: Colors.amber,
            ),
          ),
        ),
      );

      final dividerFinder = find.byType(DashedDivider);
      expect(dividerFinder, findsOneWidget);

      final divider = tester.widget<DashedDivider>(dividerFinder);
      expect(divider.height, 2.5);
      expect(divider.dashWidth, 8.0);
      expect(divider.dashSpace, 4.0);
      expect(divider.color, Colors.amber);
    });

    test('DashedDividerPainter shouldRepaint correctly', () {
      const painter1 = DashedDividerPainter(
        color: Color(0xFFE5E7EB),
        dashWidth: 5.0,
        dashSpace: 3.0,
        strokeWidth: 1.0,
      );
      const painter2 = DashedDividerPainter(
        color: Color(0xFFE5E7EB),
        dashWidth: 5.0,
        dashSpace: 3.0,
        strokeWidth: 1.0,
      );
      const painterDiffColor = DashedDividerPainter(
        color: Colors.red,
        dashWidth: 5.0,
        dashSpace: 3.0,
        strokeWidth: 1.0,
      );
      const painterDiffWidth = DashedDividerPainter(
        color: Color(0xFFE5E7EB),
        dashWidth: 7.0,
        dashSpace: 3.0,
        strokeWidth: 1.0,
      );
      const painterDiffSpace = DashedDividerPainter(
        color: Color(0xFFE5E7EB),
        dashWidth: 5.0,
        dashSpace: 5.0,
        strokeWidth: 1.0,
      );
      const painterDiffStroke = DashedDividerPainter(
        color: Color(0xFFE5E7EB),
        dashWidth: 5.0,
        dashSpace: 3.0,
        strokeWidth: 2.0,
      );

      expect(painter1.shouldRepaint(painter2), isFalse);
      expect(painter1.shouldRepaint(painterDiffColor), isTrue);
      expect(painter1.shouldRepaint(painterDiffWidth), isTrue);
      expect(painter1.shouldRepaint(painterDiffSpace), isTrue);
      expect(painter1.shouldRepaint(painterDiffStroke), isTrue);
    });
  });

  group('SportAvatar', () {
    testWidgets('renders Sepak Bola with light blue/blue thematic scheme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SportAvatar('Sepak Bola'),
          ),
        ),
      );

      expect(find.byType(SportAvatar), findsOneWidget);
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(SportAvatar), matching: find.byType(Container)),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(decoration.shape, BoxShape.rectangle);
      expect(decoration.color, const Color(0xFFE8F0FE));

      final icon = tester.widget<Icon>(find.byIcon(Icons.sports_soccer_outlined));
      expect(icon.color, const Color(0xFF1B4F9E));
      expect(icon.size, 26);
    });

    testWidgets('renders Bulu Tangkis with lavender/indigo thematic scheme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SportAvatar('Bulu Tangkis'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(SportAvatar), matching: find.byType(Container)),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFEDE7F6));

      final icon = tester.widget<Icon>(find.byIcon(Icons.sports_tennis_outlined));
      expect(icon.color, const Color(0xFF4338CA));
    });

    testWidgets('renders Pencak Silat with soft orange/dark orange thematic scheme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SportAvatar('Pencak Silat'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(SportAvatar), matching: find.byType(Container)),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFBE9E7));

      final icon = tester.widget<Icon>(find.byIcon(Icons.sports_martial_arts_outlined));
      expect(icon.color, const Color(0xFFD84315));
    });

    testWidgets('renders Renang with soft teal/dark teal thematic scheme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SportAvatar('Renang'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(SportAvatar), matching: find.byType(Container)),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFE0F2F1));

      final icon = tester.widget<Icon>(find.byIcon(Icons.pool_outlined));
      expect(icon.color, const Color(0xFF00796B));
    });

    testWidgets('renders Voli with soft amber/orange thematic scheme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SportAvatar('Voli'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(SportAvatar), matching: find.byType(Container)),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFF8E1));

      final icon = tester.widget<Icon>(find.byIcon(Icons.sports_volleyball_outlined));
      expect(icon.color, const Color(0xFFF57C00));
    });

    testWidgets('renders fallback sport with default KokColors scheme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SportAvatar('Olahraga Lain'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(SportAvatar), matching: find.byType(Container)),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, KokColors.pale);

      final icon = tester.widget<Icon>(find.byIcon(Icons.emoji_events_outlined));
      expect(icon.color, KokColors.blue);
    });

    testWidgets('supports custom size, iconSize, and color overrides', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SportAvatar(
              'Sepak Bola',
              size: 56,
              iconSize: 32,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(SportAvatar), matching: find.byType(Container)),
      );
      expect(container.constraints?.maxWidth, 56);
      expect(container.constraints?.maxHeight, 56);

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.black);

      final icon = tester.widget<Icon>(find.byIcon(Icons.sports_soccer_outlined));
      expect(icon.color, Colors.white);
      expect(icon.size, 32);
    });
  });
}
