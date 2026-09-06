import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../shared/widgets.dart';

enum CommitteeSortOption {
  defaultStructure,
  nameAsc,
  nameDesc,
  divisionAsc,
}

List<CommitteeMember> filterCommittee(
  List<CommitteeMember> members, {
  String query = '',
  String? division,
  CommitteeSortOption sortOption = CommitteeSortOption.defaultStructure,
}) {
  final q = query.trim().toLowerCase();
  final result = members.where((m) {
    final matchesQuery = q.isEmpty ||
        m.name.toLowerCase().contains(q) ||
        m.position.toLowerCase().contains(q) ||
        m.division.toLowerCase().contains(q);
    final matchesDivision = division == null ||
        division == 'all' ||
        division == 'Semua' ||
        m.division == division;
    return matchesQuery && matchesDivision;
  }).toList();

  switch (sortOption) {
    case CommitteeSortOption.defaultStructure:
      break;
    case CommitteeSortOption.nameAsc:
      result.sort((a, b) => a.name.compareTo(b.name));
      break;
    case CommitteeSortOption.nameDesc:
      result.sort((a, b) => b.name.compareTo(a.name));
      break;
    case CommitteeSortOption.divisionAsc:
      result.sort((a, b) {
        final comp = a.division.compareTo(b.division);
        if (comp != 0) return comp;
        final posComp = a.position.compareTo(b.position);
        if (posComp != 0) return posComp;
        return a.name.compareTo(b.name);
      });
      break;
  }
  return result;
}

class CommitteePage extends ConsumerStatefulWidget {
  const CommitteePage({super.key});

  @override
  ConsumerState<CommitteePage> createState() => _CommitteePageState();
}

class _CommitteePageState extends ConsumerState<CommitteePage> {
  final _search = TextEditingController();
  String? _selectedDivision;
  CommitteeSortOption _sortOption = CommitteeSortOption.defaultStructure;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _search.clear();
    _selectedDivision = null;
    _sortOption = CommitteeSortOption.defaultStructure;
  });

  void _showSortModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        final options = [
          (CommitteeSortOption.defaultStructure, 'Struktur Jabatan (Default)'),
          (CommitteeSortOption.nameAsc, 'Nama (A → Z)'),
          (CommitteeSortOption.nameDesc, 'Nama (Z → A)'),
          (CommitteeSortOption.divisionAsc, 'Bidang / Divisi (A → Z)'),
        ];

        return SafeArea(
          child: Padding(
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
                  'Urutkan Pengurus',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: KokColors.navy,
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map((opt) {
                  final isSelected = _sortOption == opt.$1;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() => _sortOption = opt.$1);
                      Navigator.pop(modalContext);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? KokColors.pale : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              opt.$2,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? KokColors.blue
                                    : const Color(0xFF17191D),
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_rounded,
                              color: KokColors.blue,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMemberDetailModal(BuildContext context, CommitteeMember m) {
    final initial =
        m.name.isNotEmpty ? m.name.substring(0, 1).toUpperCase() : '?';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F0FE),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C2464),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                m.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C2464),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  m.position,
                  style: const TextStyle(
                    color: Color(0xFF1B4F9E),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Surface(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    DetailRow('Jabatan', m.position),
                    DetailRow('Bidang', m.division),
                    DetailRow('Periode', m.period),
                    const DetailRow('Kecamatan', 'Garut Kota'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: Color(0xFF1B4F9E),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Status kepengurusan terdaftar pada SK KOK Garut Kota.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1B4F9E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(modalContext),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(snapshotProvider).asData?.value;
    final filteredCount = snapshot != null
        ? filterCommittee(
            snapshot.committee,
            query: _search.text,
            division: _selectedDivision,
            sortOption: _sortOption,
          ).length
        : null;

    final titleText = filteredCount != null
        ? 'Anggota KOK ($filteredCount)'
        : 'Anggota KOK';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titleText,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Color(0xFF17191D),
          ),
        ),
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Tooltip(
                message: 'Urutkan pengurus',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _showSortModal(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(
                      Icons.swap_vert,
                      color: KokColors.ink,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: DataView(
        builder: (data) {
          final members = filterCommittee(
            data.committee,
            query: _search.text,
            division: _selectedDivision,
            sortOption: _sortOption,
          );

          // Extract unique divisions
          final uniqueDivisions = <String>[];
          for (final m in data.committee) {
            if (!uniqueDivisions.contains(m.division)) {
              uniqueDivisions.add(m.division);
            }
          }
          final allChipItems = ['Semua', ...uniqueDivisions];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'KEPENGURUSAN KOK',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B4F9E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Kecamatan Garut Kota',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C2464),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.committee.length} pengurus · Periode 2025–2029',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF17191D),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau jabatan...',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF9CA3AF),
                      size: 22,
                    ),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: false,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Division Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: allChipItems.map((div) {
                    final isAll = div == 'Semua';
                    final isSelected = (_selectedDivision == null ||
                            _selectedDivision == 'Semua')
                        ? isAll
                        : _selectedDivision == div;
                    final count = isAll
                        ? data.committee.length
                        : data.committee
                            .where((m) => m.division == div)
                            .length;
                    final label = '$div $count';

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isAll || _selectedDivision == div) {
                              _selectedDivision = null;
                            } else {
                              _selectedDivision = div;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1B4F9E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? null
                                : Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Section Header
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Struktur kepengurusan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C2464),
                      ),
                    ),
                  ),
                  Text(
                    '${members.length} pengurus',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Committee Member List
              if (members.isEmpty)
                EmptyState(
                  message: 'Tidak ada pengurus yang cocok.',
                  onReset: _reset,
                )
              else
                ...members.map(
                  (m) => CommitteeMemberCard(
                    member: m,
                    onTap: () => _showMemberDetailModal(context, m),
                  ),
                ),
              const SizedBox(height: 8),
              const DemoNote(),
            ],
          );
        },
      ),
    );
  }
}

class CommitteeMemberCard extends StatelessWidget {
  const CommitteeMemberCard({
    super.key,
    required this.member,
    this.onTap,
  });

  final CommitteeMember member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial =
        member.name.isNotEmpty ? member.name.substring(0, 1).toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE8F0FE),
                  foregroundColor: const Color(0xFF0C2464),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF0C2464),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0C2464),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.position,
                        style: const TextStyle(
                          color: Color(0xFF1B4F9E),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${member.division} · Periode ${member.period}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
