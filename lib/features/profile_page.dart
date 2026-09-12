import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/domain/user_principal.dart';
import '../core/auth/presentation/auth_controller.dart';
import '../core/composition/app_composition.dart';
import '../core/config/deployment_profile.dart';
import '../core/preferences.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/providers/snapshot_provider.dart';
import '../shared/widgets.dart';

bool _isDemoDataMode(WidgetRef ref) {
  try {
    return ref.watch(appCompositionProvider).profile.dataMode == DataMode.demo;
  } catch (_) {
    return true;
  }
}

class AccountProfileCardPainter extends CustomPainter {
  const AccountProfileCardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.85, -20.0);
    final paint1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final paint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, 120, paint1);
    canvas.drawCircle(center, 180, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDemoData = _isDemoDataMode(ref);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Akun',
          style: TextStyle(
            fontFamily: 'KokSans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0C2464),
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ExecutiveProfileCard(user: user),
          DataView(
            builder: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('STATUS DATA KEOLAHRAGAAN'),
                _SyncStatusCard(data: data),
                _buildSectionHeader('UTILITAS KOORDINATOR'),
                _MenuTile(
                  icon: Icons.summarize_outlined,
                  iconBg: const Color(0xFFE8F0FE),
                  iconColor: const Color(0xFF1B4F9E),
                  title: 'Rekap Data Kecamatan',
                  subtitle: 'Ringkasan cabor, klub, dan atlet untuk laporan',
                  enabled: user?.hasPermission('reports:export') ?? false,
                  onTap: () => _showRekapSheet(context, data, user, ref),
                ),
                _MenuTile(
                  icon: Icons.support_agent_rounded,
                  iconBg: const Color(0xFFD1FAE5),
                  iconColor: const Color(0xFF059669),
                  title: 'Helpdesk KONI Kabupaten',
                  subtitle: 'Kontak koordinasi data dan administrasi KOK',
                  onTap: () => _showHelpdeskSheet(context, data.helpdesk),
                ),
              ],
            ),
          ),
          _buildSectionHeader('PENGATURAN & APLIKASI'),
          _MenuTile(
            icon: Icons.settings_outlined,
            iconBg: const Color(0xFFEDE9FE),
            iconColor: const Color(0xFF6D28D9),
            title: 'Pengaturan Aplikasi',
            subtitle: 'Preferensi sesi & memori nomor SK',
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => const _SettingsSheet(),
            ),
          ),
          _MenuTile(
            icon: Icons.info_outline_rounded,
            iconBg: const Color(0xFFFFEDD5),
            iconColor: const Color(0xFFEA580C),
            title: 'Tentang Aplikasi',
            subtitle: 'KOK Garut · Versi 0.1.0 (Prototipe)',
            onTap: () => _showAboutSheet(context),
          ),
          const SizedBox(height: 8),
          _LogoutButton(onPressed: () => _showSignOutDialog(context, ref)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              isDemoData
                  ? 'Data demo lokal—belum terhubung dengan SICABOR. Hubungi admin kabupaten untuk koordinasi akun.'
                  : 'Hubungi admin kabupaten untuk koordinasi akun.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    ),
  );

  void _showRekapSheet(
    BuildContext context,
    KokSnapshot data,
    UserPrincipal? user,
    WidgetRef ref,
  ) {
    if (!(user?.hasPermission('reports:export') ?? false)) return;
    final caborCount = data.clubs.map((c) => c.sport).toSet().length;
    final klubCount = data.clubs.length;
    final atletCount = data.people.where((p) => p.role == 'Atlet').length;
    final pelatihCount = data.people.where((p) => p.role == 'Pelatih').length;
    final missingCount = data.people
        .where((p) => p.missingDocuments.isNotEmpty)
        .length;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rekapitulasi Data KOK ${data.scope.name.replaceFirst('Kecamatan ', '')}',
                style: const TextStyle(
                  fontFamily: 'KokSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0C2464),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ringkasan data keolahragaan wilayah ${data.scope.name}.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: KokColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    _MetricRow(
                      label: 'Cabang Olahraga',
                      value: '$caborCount Cabor',
                      icon: Icons.emoji_events_outlined,
                      iconColor: KokColors.blue,
                    ),
                    const Divider(height: 18, color: Color(0xFFE5E7EB)),
                    _MetricRow(
                      label: 'Klub Terdaftar',
                      value: '$klubCount Klub',
                      icon: Icons.shield_outlined,
                      iconColor: const Color(0xFF059669),
                    ),
                    const Divider(height: 18, color: Color(0xFFE5E7EB)),
                    _MetricRow(
                      label: 'Total Atlet Terdata',
                      value: '$atletCount Atlet',
                      icon: Icons.directions_run_rounded,
                      iconColor: const Color(0xFF4338CA),
                    ),
                    const Divider(height: 18, color: Color(0xFFE5E7EB)),
                    _MetricRow(
                      label: 'Pelatih Terverifikasi',
                      value: '$pelatihCount Pelatih',
                      icon: Icons.sports_rounded,
                      iconColor: const Color(0xFFD97706),
                    ),
                    const Divider(height: 18, color: Color(0xFFE5E7EB)),
                    _MetricRow(
                      label: 'Berkas Belum Lengkap',
                      value: '$missingCount Berkas Kurang',
                      icon: Icons.warning_amber_rounded,
                      iconColor: const Color(0xFFDC2626),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final timeStr =
                        '${data.loadedAt.hour.toString().padLeft(2, '0')}:${data.loadedAt.minute.toString().padLeft(2, '0')}';
                    final summaryText =
                        '''
REKAPITULASI DATA ${data.scope.name.toUpperCase()}
Waktu: $timeStr WIB
Total Cabang Olahraga: $caborCount
Total Klub: $klubCount
Total Atlet: $atletCount
Total Pelatih: $pelatihCount
Total Berkas Belum Lengkap: $missingCount
Status: Terdaftar pada Sistem KOK ${data.scope.name}''';
                    final currentUser = ref.read(currentUserProvider);
                    if (!(currentUser?.hasPermission('reports:export') ??
                        false)) {
                      return;
                    }

                    try {
                      await Clipboard.setData(ClipboardData(text: summaryText));
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Teks rekapitulasi gagal disalin ke clipboard',
                            ),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                      return;
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Teks rekapitulasi berhasil disalin ke clipboard',
                          ),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Salin Teks Rekapitulasi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpdeskSheet(BuildContext context, HelpdeskContact? helpdesk) {
    final hasHelpdeskData =
        helpdesk != null &&
        [
          helpdesk.whatsapp,
          helpdesk.phone,
          helpdesk.email,
          helpdesk.address,
          helpdesk.operationalHours,
        ].any((value) => value != null && value.trim().isNotEmpty);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Helpdesk & Sekretariat KONI',
                style: TextStyle(
                  fontFamily: 'KokSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0C2464),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Hubungi sekretariat KONI Kabupaten Garut untuk konsultasi dan koordinasi sistem.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 18),
              if (!hasHelpdeskData)
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Text(
                    'Data helpdesk belum tersedia.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                )
              else ...[
                _ContactItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconBg: const Color(0xFFD1FAE5),
                  iconColor: const Color(0xFF059669),
                  title: 'WhatsApp Helpdesk',
                  subtitle: _displayValue(helpdesk.whatsapp),
                ),
                _ContactItem(
                  icon: Icons.phone_outlined,
                  iconBg: const Color(0xFFE8F0FE),
                  iconColor: const Color(0xFF1B4F9E),
                  title: 'Telepon Kantor',
                  subtitle: _displayValue(helpdesk.phone),
                ),
                _ContactItem(
                  icon: Icons.email_outlined,
                  iconBg: const Color(0xFFEDE9FE),
                  iconColor: const Color(0xFF6D28D9),
                  title: 'Email Resmi',
                  subtitle: _displayValue(helpdesk.email),
                ),
                _ContactItem(
                  icon: Icons.location_on_outlined,
                  iconBg: const Color(0xFFFFEDD5),
                  iconColor: const Color(0xFFEA580C),
                  title: 'Alamat Sekretariat',
                  subtitle: _displayValue(helpdesk.address),
                ),
                if (_hasValue(helpdesk.operationalHours)) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      'Jam Layanan Operasional: ${helpdesk.operationalHours}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _displayValue(String? value) => _hasValue(value) ? value! : '-';

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tentang Aplikasi',
                style: TextStyle(
                  fontFamily: 'KokSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0C2464),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KOK — Koordinator Organisasi Kecamatan',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0C2464),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'KOK Garut · Versi 0.1.0 (Prototipe)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: KokColors.blue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Aplikasi KOK Garut Kota dikembangkan sebagai media pendataan, pemantauan kegiatan cabang olahraga, klub binaan, serta verifikasi keabsahan data atlet dan pelatih di tingkat kecamatan.',
                      style: TextStyle(fontSize: 13, height: 1.45),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Kerja Sama: KONI Kabupaten Garut & Dispora Garut.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Data terdaftar merupakan ilustrasi persiapan integrasi sistem data SICABOR Kabupaten Garut. Hak cipta dilindungi.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isLoggingOut = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFDC2626),
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Keluar dari Akun?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'KokSans',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0C2464),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sesi Anda akan berakhir. Anda perlu memasukkan kembali nomor SK KOK untuk masuk ke aplikasi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4B5563),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: TextButton(
                            onPressed: isLoggingOut
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Batal',
                              style: TextStyle(
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isLoggingOut
                                ? null
                                : () async {
                                    setDialogState(() => isLoggingOut = true);
                                    try {
                                      await ref
                                          .read(authControllerProvider.notifier)
                                          .logout();
                                    } finally {
                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isLoggingOut
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Ya, Keluar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExecutiveProfileCard extends StatelessWidget {
  const _ExecutiveProfileCard({this.user});
  final UserPrincipal? user;

  @override
  Widget build(BuildContext context) {
    final name = user?.fullName ?? 'Pak Asep';
    final initials = user != null
        ? user!.fullName
              .split(' ')
              .where((s) => s.isNotEmpty)
              .map((s) => s[0])
              .take(2)
              .join()
              .toUpperCase()
        : 'PA';
    final roleTitle = user?.roleTitle ?? 'Koordinator Kecamatan';
    final scopeName = user?.scope.name ?? 'Kecamatan Garut Kota';
    final subtitle =
        '$roleTitle · ${scopeName.replaceFirst('Kecamatan ', 'Kec. ')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07237B), Color(0xFF03144B)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF07237B).withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CustomPaint(
          painter: const AccountProfileCardPainter(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E3A8A),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.40),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFF59E0B),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          user?.scope.type == AccessScopeType.county
                              ? 'AKSES KABUPATEN'
                              : 'AKSES READ-ONLY',
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncStatusCard extends ConsumerWidget {
  const _SyncStatusCard({required this.data});
  final KokSnapshot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemoData = _isDemoDataMode(ref);
    final demoBadge = isDemoData ? ' (Mode Demo)' : '';
    final timeStr =
        '${data.loadedAt.hour.toString().padLeft(2, '0')}:${data.loadedAt.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: KokColors.ink.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Terakhir dimuat: $timeStr · ${data.people.length} entri data$demoBadge',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: KokColors.cardTitle,
                  ),
                ),
              ),
              Material(
                color: const Color(0xFFE8F0FE),
                shape: const CircleBorder(),
                child: IconButton(
                  iconSize: 20,
                  tooltip: 'Muat ulang data',
                  onPressed: () async {
                    ref.invalidate(snapshotProvider);
                    try {
                      await ref.read(snapshotProvider.future);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Data berhasil dimuat ulang'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (_) {}
                  },
                  icon: const Icon(
                    Icons.sync_rounded,
                    color: Color(0xFF1B4F9E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const DashedDivider(color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),
          Text(
            isDemoData
                ? 'Status koneksi: Data demo lokal—belum terhubung dengan SICABOR.'
                : 'Status koneksi: Terhubung dengan SICABOR.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveSubtitle = enabled
        ? subtitle
        : 'Fitur tidak tersedia untuk peran ini';
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Surface(
        onTap: enabled ? onTap : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: KokColors.cardTitle,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    effectiveSubtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 20),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: iconColor),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: Color(0xFF0C2464),
        ),
      ),
    ],
  );
}

class _ContactItem extends StatelessWidget {
  const _ContactItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFFFEF2F2),
        side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
      label: const Text(
        'Keluar dari Akun',
        style: TextStyle(
          color: Color(0xFFDC2626),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final prefs = ref.read(preferencesProvider);
    final hasKey = prefs.containsKey('remembered_sk');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pengaturan Aplikasi',
              style: TextStyle(
                fontFamily: 'KokSans',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0C2464),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasKey
                  ? 'Nomor SK diingat di perangkat ini (${prefs.getString('remembered_sk') ?? ''}).'
                  : 'Tidak ada nomor SK tersimpan.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: hasKey
                    ? () async {
                        await prefs.remove('remembered_sk');
                        if (mounted) setState(() {});
                      }
                    : null,
                label: const Text('Hapus nomor SK tersimpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
