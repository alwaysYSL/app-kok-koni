import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/shared/remote_feature_placeholder.dart';

void main() {
  group('RemoteFeaturePlaceholder Tests', () {
    testWidgets('renders default icon, featureName, and description', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RemoteFeaturePlaceholder(
              featureName: 'Fitur Pengujian',
              description: 'Deskripsi fitur pengujian.',
            ),
          ),
        ),
      );

      expect(find.text('Fitur Pengujian'), findsOneWidget);
      expect(find.text('Deskripsi fitur pengujian.'), findsOneWidget);
      expect(find.byIcon(Icons.construction_outlined), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('renders custom icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RemoteFeaturePlaceholder(
              featureName: 'Pencarian Global',
              description: 'Deskripsi pencarian.',
              icon: Icons.search_off_rounded,
            ),
          ),
        ),
      );

      expect(find.text('Pencarian Global'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });

    testWidgets(
      'renders without description when description is null or empty',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RemoteFeaturePlaceholder(featureName: 'Tanpa Deskripsi'),
            ),
          ),
        );

        expect(find.text('Tanpa Deskripsi'), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
      },
    );

    testWidgets('renders action button and triggers onAction callback', (
      tester,
    ) async {
      var actionCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteFeaturePlaceholder(
              featureName: 'Fitur Beraksi',
              description: 'Tekan tombol di bawah ini.',
              actionText: 'Kembali ke Beranda',
              onAction: () {
                actionCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Kembali ke Beranda'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);

      await tester.tap(find.text('Kembali ke Beranda'));
      await tester.pumpAndSettle();

      expect(actionCalled, isTrue);
    });

    testWidgets(
      'does not render button if only actionText is provided without callback',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RemoteFeaturePlaceholder(
                featureName: 'Fitur Teks Saja',
                actionText: 'Teks Tombol',
              ),
            ),
          ),
        );

        expect(find.text('Teks Tombol'), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
      },
    );
  });
}
