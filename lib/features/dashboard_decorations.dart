import 'package:flutter/material.dart';

/// Latar belakang dekoratif untuk header Beranda dengan gradasi royal navy,
/// aksen garis lengkung emas/cyan, dan matriks titik di kanan atas.
class DashboardHeaderDecoration extends StatelessWidget {
  const DashboardHeaderDecoration({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
          colors: [
            Color(0xFF07237B),
            Color(0xFF03144B),
          ],
        ),
      ),
      child: CustomPaint(
        painter: const DashboardHeaderPainter(),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// CustomPainter untuk menggambar aksen dot matrix dan kurva lengkung header.
class DashboardHeaderPainter extends CustomPainter {
  const DashboardHeaderPainter();

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
    const startY = 14.0;

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
      ..moveTo(0, size.height * 0.20)
      ..cubicTo(
        size.width * 0.30,
        size.height * 0.18,
        size.width * 0.20,
        size.height * 0.65,
        0,
        size.height * 0.85,
      );

    final cyanPath = Path()
      ..moveTo(0, size.height * 0.10)
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.12,
        size.width * 0.32,
        size.height * 0.72,
        0,
        size.height * 0.95,
      );

    canvas.drawPath(cyanPath, cyanLinePaint);
    canvas.drawPath(goldPath, goldLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Komponen siluet pelari / atlet dinamis artistik berbasis Flutter Canvas
/// dengan nuansa biru lembut (Color(0xFF1B4F9E)) untuk floating stats card.
class AthletesSilhouetteGraphic extends StatelessWidget {
  const AthletesSilhouetteGraphic({
    super.key,
    this.width = 140,
    this.height = 95,
    this.primaryColor = const Color(0xFF1B4F9E),
  });

  final double width;
  final double height;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: AthletesSilhouettePainter(primaryColor: primaryColor),
      ),
    );
  }
}

/// CustomPainter untuk menggambar siluet dinamis sekelompok pelari/atlet.
class AthletesSilhouettePainter extends CustomPainter {
  const AthletesSilhouettePainter({
    this.primaryColor = const Color(0xFF1B4F9E),
  });

  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Gambar lintasan lari / garis dinamis halus di bawah atlet
    _drawTrackLines(canvas, size);

    // 2. Gambar garis kecepatan / motion streaks di belakang pelari
    _drawSpeedStreaks(canvas, size);

    // 3. Gambar pelari latar belakang (runner 3 - paling jauh, paling lembut)
    _drawRunner(
      canvas,
      center: Offset(size.width * 0.85, size.height * 0.42),
      scale: (size.height / 100.0) * 0.68,
      color: primaryColor.withValues(alpha: 0.22),
      legVariation: 2,
    );

    // 4. Gambar pelari menengah (runner 2 - transisi tengah)
    _drawRunner(
      canvas,
      center: Offset(size.width * 0.65, size.height * 0.46),
      scale: (size.height / 100.0) * 0.82,
      color: primaryColor.withValues(alpha: 0.45),
      legVariation: 1,
    );

    // 5. Gambar pelari utama (lead runner - paling depan & tajam)
    _drawRunner(
      canvas,
      center: Offset(size.width * 0.40, size.height * 0.50),
      scale: (size.height / 100.0) * 1.0,
      color: primaryColor.withValues(alpha: 0.88),
      legVariation: 0,
    );
  }

  void _drawTrackLines(Canvas canvas, Size size) {
    final trackPaint1 = Paint()
      ..color = primaryColor.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final trackPaint2 = Paint()
      ..color = primaryColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final trackPath1 = Path()
      ..moveTo(size.width * 0.05, size.height * 0.94)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.92,
        size.width * 0.68,
        size.height * 0.84,
        size.width * 0.98,
        size.height * 0.72,
      );

    final trackPath2 = Path()
      ..moveTo(size.width * 0.15, size.height * 0.98)
      ..cubicTo(
        size.width * 0.48,
        size.height * 0.96,
        size.width * 0.75,
        size.height * 0.90,
        size.width,
        size.height * 0.80,
      );

    canvas.drawPath(trackPath1, trackPaint1);
    canvas.drawPath(trackPath2, trackPaint2);
  }

  void _drawSpeedStreaks(Canvas canvas, Size size) {
    final streakPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.26),
      Offset(size.width * 0.96, size.height * 0.26),
      streakPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.62, size.height * 0.36),
      Offset(size.width * 0.90, size.height * 0.36),
      streakPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.46),
      Offset(size.width * 0.98, size.height * 0.46),
      streakPaint,
    );
  }

  void _drawRunner(
    Canvas canvas, {
    required Offset center,
    required double scale,
    required Color color,
    required int legVariation,
  }) {
    // 1. Kepala pelari
    final headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx - 4 * scale, center.dy - 32 * scale),
      6.2 * scale,
      headPaint,
    );

    // 2. Tubuh / Torso atletis condong ke depan
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final torsoPath = Path()
      ..moveTo(center.dx - 6 * scale, center.dy - 24 * scale)
      ..quadraticBezierTo(
        center.dx - 15 * scale,
        center.dy - 16 * scale,
        center.dx - 11 * scale,
        center.dy - 1 * scale,
      )
      ..lineTo(center.dx - 6 * scale, center.dy + 8 * scale)
      ..lineTo(center.dx + 4 * scale, center.dy + 6 * scale)
      ..quadraticBezierTo(
        center.dx + 7 * scale,
        center.dy - 10 * scale,
        center.dx,
        center.dy - 23 * scale,
      )
      ..close();

    canvas.drawPath(torsoPath, bodyPaint);

    // 3. Tangan mengayun
    final armPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.6 * scale;

    final backArmPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.75)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.2 * scale;

    // Lengan depan (mengayun ke kiri depan)
    final frontArmPath = Path()
      ..moveTo(center.dx - 8 * scale, center.dy - 18 * scale)
      ..lineTo(center.dx - 20 * scale, center.dy - 10 * scale)
      ..lineTo(center.dx - 14 * scale, center.dy - 23 * scale);

    // Lengan belakang (mengayun ke belakang)
    final backArmPath = Path()
      ..moveTo(center.dx + 3 * scale, center.dy - 17 * scale)
      ..lineTo(center.dx + 16 * scale, center.dy - 9 * scale)
      ..lineTo(center.dx + 11 * scale, center.dy + 3 * scale);

    canvas.drawPath(backArmPath, backArmPaint);
    canvas.drawPath(frontArmPath, armPaint);

    // 4. Kaki atlet melangkah cepat / sprint stride
    final leadLegPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4.2 * scale;

    final backLegPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.80)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.8 * scale;

    final leadLegPath = Path();
    final backLegPath = Path();

    if (legVariation == 0) {
      // Langkah lebar: kaki depan terangkat tinggi melangkah ke depan
      leadLegPath
        ..moveTo(center.dx - 6 * scale, center.dy + 8 * scale)
        ..lineTo(center.dx - 22 * scale, center.dy + 18 * scale)
        ..lineTo(center.dx - 16 * scale, center.dy + 38 * scale)
        ..lineTo(center.dx - 24 * scale, center.dy + 39 * scale);

      backLegPath
        ..moveTo(center.dx + 2 * scale, center.dy + 7 * scale)
        ..lineTo(center.dx + 18 * scale, center.dy + 17 * scale)
        ..lineTo(center.dx + 30 * scale, center.dy + 12 * scale)
        ..lineTo(center.dx + 35 * scale, center.dy + 10 * scale);
    } else if (legVariation == 1) {
      // Langkah kontak tanah: kaki depan menjejak, kaki belakang melipat naik
      leadLegPath
        ..moveTo(center.dx - 5 * scale, center.dy + 8 * scale)
        ..lineTo(center.dx - 16 * scale, center.dy + 22 * scale)
        ..lineTo(center.dx - 12 * scale, center.dy + 40 * scale)
        ..lineTo(center.dx - 20 * scale, center.dy + 40 * scale);

      backLegPath
        ..moveTo(center.dx + 3 * scale, center.dy + 7 * scale)
        ..lineTo(center.dx + 14 * scale, center.dy + 15 * scale)
        ..lineTo(center.dx + 24 * scale, center.dy + 26 * scale)
        ..lineTo(center.dx + 29 * scale, center.dy + 25 * scale);
    } else {
      // Langkah dorongan kuat
      leadLegPath
        ..moveTo(center.dx - 5 * scale, center.dy + 8 * scale)
        ..lineTo(center.dx - 20 * scale, center.dy + 16 * scale)
        ..lineTo(center.dx - 18 * scale, center.dy + 35 * scale)
        ..lineTo(center.dx - 25 * scale, center.dy + 36 * scale);

      backLegPath
        ..moveTo(center.dx + 2 * scale, center.dy + 7 * scale)
        ..lineTo(center.dx + 16 * scale, center.dy + 19 * scale)
        ..lineTo(center.dx + 26 * scale, center.dy + 16 * scale)
        ..lineTo(center.dx + 31 * scale, center.dy + 14 * scale);
    }

    canvas.drawPath(backLegPath, backLegPaint);
    canvas.drawPath(leadLegPath, leadLegPaint);
  }

  @override
  bool shouldRepaint(covariant AthletesSilhouettePainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor;
  }
}

/// CustomPainter untuk menggambar pola latar belakang header merek/aplikasi
/// dengan matriks titik di kanan atas dan busur lingkaran konsentris di kiri/tengah atas.
class BrandHeaderPatternPainter extends CustomPainter {
  const BrandHeaderPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Gambar Dot Matrix di kanan atas
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    const rows = 7;
    const cols = 6;
    const spacing = 14.0;
    final startX = size.width - (cols * spacing) - 14.0;
    const startY = 14.0;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset(startX + (c * spacing), startY + (r * spacing)),
          1.8,
          dotPaint,
        );
      }
    }

    // 2. Gambar Concentric Circular Arcs (busur lingkaran halus) di kiri atas
    final center = Offset(size.width * 0.12, -30.0);

    final arcPaint1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final arcPaint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, 130.0, arcPaint1);
    canvas.drawCircle(center, 190.0, arcPaint1);
    canvas.drawCircle(center, 260.0, arcPaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

