import 'package:flutter/material.dart';

import '../../core/theme.dart';

class BodySilhouette extends StatelessWidget {
  const BodySilhouette({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Ilustrasi tubuh manusia',
    child: CustomPaint(
      size: const Size(88, 150),
      painter: const _BodySilhouettePainter(),
    ),
  );
}

class _BodySilhouettePainter extends CustomPainter {
  const _BodySilhouettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 88, size.height / 150);
    final fill = Paint()..color = KokColors.blue;
    final limbs = Paint()
      ..color = KokColors.blue
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawOval(const Rect.fromLTWH(34, 5, 22, 25), fill);
    final torso = Path()
      ..moveTo(33, 37)
      ..quadraticBezierTo(44, 32, 56, 37)
      ..lineTo(62, 84)
      ..quadraticBezierTo(44, 91, 27, 84)
      ..close();
    canvas.drawPath(torso, fill);
    canvas.drawLine(const Offset(35, 43), const Offset(20, 75), limbs);
    canvas.drawLine(const Offset(20, 75), const Offset(16, 91), limbs);
    canvas.drawLine(const Offset(54, 43), const Offset(69, 75), limbs);
    canvas.drawLine(const Offset(69, 75), const Offset(73, 91), limbs);
    canvas.drawLine(const Offset(37, 84), const Offset(34, 116), limbs);
    canvas.drawLine(const Offset(34, 116), const Offset(29, 144), limbs);
    canvas.drawLine(const Offset(53, 84), const Offset(56, 116), limbs);
    canvas.drawLine(const Offset(56, 116), const Offset(61, 144), limbs);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
