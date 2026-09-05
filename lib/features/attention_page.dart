import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../shared/widgets.dart';

class AttentionPage extends StatefulWidget {
  const AttentionPage({super.key, this.type});

  final String? type;

  @override
  State<AttentionPage> createState() => _AttentionPageState();
}

class _AttentionPageState extends State<AttentionPage> {
  late String _type = widget.type ?? 'all';

  @override
  void didUpdateWidget(AttentionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.type != oldWidget.type) {
      _type = widget.type ?? 'all';
    }
  }

  void _showInfoModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Informasi Kualitas Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: KokColors.navy,
                ),
              ),
              const SizedBox(height: 14),
              _infoItem(
                icon: Icons.description_outlined,
                title: 'Berkas Atlet',
                desc:
                    'Atlet yang belum melengkapi dokumen wajib seperti Kartu Keluarga, Akta Kelahiran, atau Surat Sehat.',
              ),
              const SizedBox(height: 12),
              _infoItem(
                icon: Icons.card_membership_outlined,
                title: 'Lisensi Pelatih',
                desc:
                    'Pelatih yang masa berlaku lisensi kepelatihannya telah kedaluwarsa dan perlu diperbarui.',
              ),
              const SizedBox(height: 12),
              _infoItem(
                icon: Icons.sync_problem_outlined,
                title: 'Koordinasi Tindak Lanjut',
                desc:
                    'Hubungi ketua pengurus cabang olahraga atau klub terkait untuk melakukan verifikasi dan pembaruan data fisik.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(modalContext),
                  style: FilledButton.styleFrom(
                    backgroundColor: KokColors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Mengerti'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: KokColors.pale,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: KokColors.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF17191D),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B4F9E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF1B4F9E) : const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Text(
            '$label $count',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF374151),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DataView(
      builder: (data) {
        final docCount = data.people.where((p) => p.missingDocuments.isNotEmpty).length;
        final licenseCount = data.people.where((p) => p.expiredLicense).length;
        final totalCount = data.people
            .where((p) => p.missingDocuments.isNotEmpty || p.expiredLicense)
            .length;

        final filteredPeople = data.people
            .where(
              (p) => switch (_type) {
                'documents' => p.missingDocuments.isNotEmpty,
                'license' => p.expiredLicense,
                _ => p.missingDocuments.isNotEmpty || p.expiredLicense,
              },
            )
            .toList();

        return Scaffold(
          backgroundColor: KokColors.background,
          appBar: AppBar(
            title: Text(
              'Perlu Perhatian (${filteredPeople.length})',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: Color(0xFF17191D),
              ),
            ),
            shape: const Border(
              bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.chevron_left,
                size: 28,
                color: Color(0xFF17191D),
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  onTap: () => _showInfoModal(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF1B4F9E),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'Semua',
                      count: totalCount,
                      isSelected: _type == 'all',
                      onTap: () => setState(() => _type = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Berkas Atlet',
                      count: docCount,
                      isSelected: _type == 'documents',
                      onTap: () => setState(() => _type = 'documents'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Lisensi',
                      count: licenseCount,
                      isSelected: _type == 'license',
                      onTap: () => setState(() => _type = 'license'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Temuan kualitas data untuk koordinasi',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 12),
              if (filteredPeople.isEmpty)
                const EmptyState(message: 'Tidak ada data yang perlu ditinjau.')
              else
                ...filteredPeople.map((person) {
                  final club = data.clubs.firstWhere(
                    (c) => c.id == person.clubId,
                    orElse: () => Club(
                      id: person.clubId,
                      name: 'Klub',
                      sport: 'Olahraga',
                      village: '-',
                    ),
                  );
                  return AttentionCard(person: person, club: club);
                }),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Tindak lanjuti temuan di atas dengan menghubungi ketua pengurus klub bersangkutan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const DemoNote(),
            ],
          ),
        );
      },
    );
  }
}

class AttentionCard extends StatelessWidget {
  const AttentionCard({
    super.key,
    required this.person,
    required this.club,
  });

  final SportPerson person;
  final Club club;

  String get issueText {
    if (person.missingDocuments.isNotEmpty && person.expiredLicense) {
      return '${person.missingDocuments.join(' & ')} kurang & Lisensi kedaluwarsa';
    }
    if (person.missingDocuments.isNotEmpty) {
      return '${person.missingDocuments.join(' & ')} kurang';
    }
    if (person.expiredLicense) {
      return 'Lisensi kedaluwarsa';
    }
    return 'Perlu ditinjau';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/person/${person.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: KokColors.pale,
                      child: Icon(
                        person.role == 'Pelatih'
                            ? Icons.person_rounded
                            : Icons.directions_run_rounded,
                        color: const Color(0xFF1B4F9E),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF0C2464),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${club.name} · ${club.sport} ${person.group}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF9CA3AF),
                      size: 20,
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: DashedDivider(
                    color: Color(0xFFE5E7EB),
                    dashWidth: 5,
                    dashSpace: 3,
                    height: 1,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        issueText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFDC2626),
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
