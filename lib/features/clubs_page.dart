import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/club_filters.dart';
import '../data/providers/snapshot_provider.dart';
import '../shared/widgets.dart';

class ClubsPage extends ConsumerStatefulWidget {
  const ClubsPage({super.key, this.sport});
  final String? sport;
  @override
  ConsumerState<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends ConsumerState<ClubsPage> {
  final _search = TextEditingController();
  String? _sport, _status, _village;
  ClubSortOption _sortOption = ClubSortOption.nameAsc;

  @override
  void initState() {
    super.initState();
    _sport = widget.sport;
  }

  @override
  void didUpdateWidget(ClubsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sport != oldWidget.sport) {
      _sport = widget.sport;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _search.clear();
    _sport = widget.sport;
    _status = null;
    _village = null;
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
          (ClubSortOption.nameAsc, 'Nama (A → Z)'),
          (ClubSortOption.nameDesc, 'Nama (Z → A)'),
          (ClubSortOption.athletesDesc, 'Jumlah Atlet Terbanyak'),
          (ClubSortOption.statusActiveFirst, 'Status (Aktif Terlebih Dahulu)'),
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
                  'Urutkan Klub',
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

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(snapshotProvider).asData?.value;
    final filteredCount = snapshot != null
        ? filterClubs(
            snapshot.clubs,
            query: _search.text,
            sport: _sport,
            status: _status,
            village: _village,
            sortOption: _sortOption,
            snapshot: snapshot,
          ).length
        : null;

    final titlePrefix = widget.sport ?? 'Klub';
    final titleText = filteredCount != null
        ? '$titlePrefix ($filteredCount)'
        : titlePrefix;

    final hasActiveFilter =
        (_sport != widget.sport) ||
        (_status != null) ||
        (_village != null) ||
        _search.text.isNotEmpty;

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
        leading: (widget.sport != null || Navigator.canPop(context))
            ? IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  size: 28,
                  color: KokColors.cardTitle,
                ),
                tooltip: 'Kembali',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/sports');
                  }
                },
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Tooltip(
                message: 'Urutkan klub',
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
          final clubs = filterClubs(
            data.clubs,
            query: _search.text,
            sport: _sport,
            status: _status,
            village: _village,
            sortOption: _sortOption,
            snapshot: data,
          );
          final caborCount = clubs.map((c) => c.sport).toSet().length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                    hintText: 'Cari nama klub...',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9E9E9E),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF9E9E9E),
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
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    filled: false,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    InkWell(
                      onTap: _reset,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: !hasActiveFilter
                              ? KokColors.blue
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: !hasActiveFilter
                              ? null
                              : Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          'Semua',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: !hasActiveFilter
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: !hasActiveFilter
                                ? Colors.white
                                : const Color(0xFF17191D),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.sport == null) ...[
                      FilterChipDropdown(
                        label: 'Cabor',
                        value: _sport,
                        options: data.clubs.map((c) => c.sport).toSet().toList()
                          ..sort(),
                        onChanged: (v) => setState(() => _sport = v),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilterChipDropdown(
                      label: 'Status',
                      value: _status,
                      options: const ['Aktif', 'Pasif'],
                      onChanged: (v) => setState(() => _status = v),
                    ),
                    const SizedBox(width: 8),
                    FilterChipDropdown(
                      label: 'Kelurahan',
                      value: _village,
                      displayValue: _village ?? 'Kel.',
                      options: data.clubs.map((c) => c.village).toSet().toList()
                        ..sort(),
                      onChanged: (v) => setState(() => _village = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  '${clubs.length} klub · $caborCount cabor',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF727782),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (clubs.isEmpty) EmptyState(onReset: _reset),
              ...clubs.map((c) => ClubTile(club: c, data: data)),
              const DemoNote(),
            ],
          );
        },
      ),
    );
  }
}

class FilterChipDropdown extends StatelessWidget {
  const FilterChipDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.displayValue,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String? displayValue;

  @override
  Widget build(BuildContext context) {
    final isSelected = value != null;
    final text = displayValue ?? value ?? label;

    return PopupMenuButton<String>(
      tooltip: 'Filter $label',
      initialValue: value ?? '',
      onSelected: (v) => onChanged(v.isEmpty ? null : v),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: '',
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Semua $label',
                  style: TextStyle(
                    fontWeight: !isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: !isSelected
                        ? KokColors.blue
                        : const Color(0xFF17191D),
                  ),
                ),
              ),
              if (!isSelected)
                const Icon(
                  Icons.check_rounded,
                  color: KokColors.blue,
                  size: 18,
                ),
            ],
          ),
        ),
        ...options.map(
          (o) => PopupMenuItem(
            value: o,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    o,
                    style: TextStyle(
                      fontWeight: value == o
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: value == o
                          ? KokColors.blue
                          : const Color(0xFF17191D),
                    ),
                  ),
                ),
                if (value == o)
                  const Icon(
                    Icons.check_rounded,
                    color: KokColors.blue,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFB9D3FC)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? KokColors.blue : const Color(0xFF17191D),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isSelected ? KokColors.blue : const Color(0xFF727782),
            ),
          ],
        ),
      ),
    );
  }
}

typedef FilterMenu = FilterChipDropdown;

class ClubTile extends StatelessWidget {
  const ClubTile({
    super.key,
    required this.club,
    required this.data,
    this.compact = false,
  });

  final Club club;
  final KokSnapshot data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final people = clubPeople(data, club.id);
    final atletCount = people.where((p) => p.role == 'Atlet').length;
    final pelatihCount = people.where((p) => p.role == 'Pelatih').length;
    final officialCount = people.where((p) => p.role == 'Official').length;
    final missing = people.where((p) => p.missingDocuments.isNotEmpty).length;

    return Surface(
      onTap: () => context.push('/club/${club.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SportAvatar(club.sport),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: KokColors.cardTitle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${club.sport} · ${compact ? '$atletCount atlet' : club.village}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (compact)
                const Icon(Icons.chevron_right, color: KokColors.muted)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: club.active
                        ? const Color(0xFFE8F0FE)
                        : const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    club.active ? 'Aktif' : 'Pasif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: club.active
                          ? const Color(0xFF1B4F9E)
                          : const Color(0xFF757575),
                    ),
                  ),
                ),
            ],
          ),
          if (!compact) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: DashedDivider(color: Color(0xFFE5E7EB)),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$atletCount atlet · $pelatihCount pelatih · $officialCount official',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF727782),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (missing > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEAEA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$missing berkas',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
