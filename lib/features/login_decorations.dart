import 'package:flutter/material.dart';

class LoginHeaderDecoration extends StatelessWidget {
  const LoginHeaderDecoration({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 28),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF07237B), Color(0xFF03144B)],
        ),
      ),
      child: CustomPaint(
        painter: const LoginHeaderPainter(),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class LoginHeaderPainter extends CustomPainter {
  const LoginHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Gambar Dot Matrix di kanan atas
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    const rows = 8;
    const cols = 6;
    const spacing = 14.0;
    final startX = size.width - (cols * spacing) - 12;
    const startY = 16.0;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset(startX + (c * spacing), startY + (r * spacing)),
          1.8,
          dotPaint,
        );
      }
    }

    // 2. Gambar Kurva Lengkung Elegan di kiri atas
    final goldLinePaint = Paint()
      ..color = const Color(0xFFE2B743).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final cyanLinePaint = Paint()
      ..color = const Color(0xFF1E88E5).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final goldPath = Path()
      ..moveTo(0, size.height * 0.10)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.08,
        size.width * 0.15,
        size.height * 0.38,
        0,
        size.height * 0.46,
      );

    final cyanPath = Path()
      ..moveTo(0, size.height * 0.04)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.05,
        size.width * 0.25,
        size.height * 0.44,
        0,
        size.height * 0.54,
      );

    canvas.drawPath(cyanPath, cyanLinePaint);
    canvas.drawPath(goldPath, goldLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
