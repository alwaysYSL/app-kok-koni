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

class SportAvatar extends StatelessWidget {
  const SportAvatar(this.sport, {super.key});
  final String sport;
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: KokColors.pale,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(sportIcon(sport), color: KokColors.blue, size: 26),
  );
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
