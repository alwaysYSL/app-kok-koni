import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';

class DataView extends ConsumerWidget {
  const DataView({super.key, required this.builder});
  final Widget Function(KokSnapshot) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(snapshotProvider)
      .when(
        data: builder,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 44,
                  color: KokColors.muted,
                ),
                const SizedBox(height: 16),
                const Text('Data belum dapat dimuat.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(snapshotProvider),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.border,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? border;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: KokColors.ink.withValues(alpha: .045),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border ?? Colors.transparent),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.warning = false});
  final String label;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFEEEE) : KokColors.pale,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: warning ? KokColors.red : KokColors.ink,
      ),
    ),
  );
}

class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.onTap});
  final String title;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (onTap != null)
          TextButton(onPressed: onTap, child: const Text('Lihat semua ›')),
      ],
    ),
  );
}

class DemoNote extends StatelessWidget {
  const DemoNote({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Text(
      'MODE DEMO · Data ilustrasi, belum terhubung SICABOR',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: KokColors.muted),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.message = 'Tidak ada hasil yang sesuai.',
    this.onReset,
  });
  final String message;
  final VoidCallback? onReset;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 16),
    child: Column(
      children: [
        const Icon(Icons.search_off_rounded, size: 44, color: KokColors.muted),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (onReset != null)
          TextButton(onPressed: onReset, child: const Text('Reset filter')),
      ],
    ),
  );
}

IconData sportIcon(String sport) => switch (sport) {
  'Sepak Bola' => Icons.sports_soccer_outlined,
  'Bulu Tangkis' => Icons.sports_tennis_outlined,
  'Pencak Silat' => Icons.sports_martial_arts_outlined,
  'Voli' => Icons.sports_volleyball_outlined,
  'Renang' => Icons.pool_outlined,
  _ => Icons.emoji_events_outlined,
};

({Color background, Color foreground}) sportThematicColors(String sport) => switch (sport) {
  'Sepak Bola' => (
    background: const Color(0xFFE8F0FE),
    foreground: const Color(0xFF1B4F9E),
  ),
  'Bulu Tangkis' => (
    background: const Color(0xFFEDE7F6),
    foreground: const Color(0xFF4338CA),
  ),
  'Pencak Silat' => (
    background: const Color(0xFFFBE9E7),
    foreground: const Color(0xFFD84315),
  ),
  'Renang' => (
    background: const Color(0xFFE0F2F1),
    foreground: const Color(0xFF00796B),
  ),
  'Voli' => (
    background: const Color(0xFFFFF8E1),
    foreground: const Color(0xFFF57C00),
  ),
  _ => (
    background: KokColors.pale,
    foreground: KokColors.blue,
  ),
};

class SportAvatar extends StatelessWidget {
  const SportAvatar(
    this.sport, {
    super.key,
    this.size = 44,
    this.iconSize = 26,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String sport;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = sportThematicColors(sport);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.background,
        borderRadius: BorderRadius.circular(12),
        shape: BoxShape.rectangle,
      ),
      child: Icon(
        sportIcon(sport),
        color: foregroundColor ?? colors.foreground,
        size: iconSize,
      ),
    );
  }
}

class DashedDivider extends StatelessWidget {
  const DashedDivider({
    super.key,
    this.height = 1.0,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
    this.color = const Color(0xFFE5E7EB),
  });

  final double height;
  final double dashWidth;
  final double dashSpace;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            size: Size(width, height),
            painter: DashedDividerPainter(
              color: color,
              dashWidth: dashWidth,
              dashSpace: dashSpace,
              strokeWidth: height,
            ),
          ),
        );
      },
    );
  }
}

class DashedDividerPainter extends CustomPainter {
  const DashedDividerPainter({
    required this.color,
    required this.dashWidth,
    required this.dashSpace,
    required this.strokeWidth,
  });

  final Color color;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (dashWidth <= 0 || dashSpace <= 0 || strokeWidth <= 0 || size.width <= 0) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    double startX = 0;
    while (startX < size.width) {
      final endX = (startX + dashWidth).clamp(0.0, size.width);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant DashedDividerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(label, style: const TextStyle(color: KokColors.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}
