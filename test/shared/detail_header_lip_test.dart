import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/shared/detail_header_lip.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('detail header lip fits a $width dp screen', (tester) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DetailHeaderLip(header: SizedBox(height: 180))),
        ),
      );

      expect(tester.takeException(), isNull);
      final lip = find.byKey(const Key('detail-header-lip'));
      expect(lip, findsOneWidget);
      expect(tester.getSize(lip), Size(width, 28));
      expect(tester.getTopLeft(lip), const Offset(0, 152));
      final decoration =
          tester.widget<Container>(lip).decoration! as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(
        decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(28)),
      );
    });
  }
}
