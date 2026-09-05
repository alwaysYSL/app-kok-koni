import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import 'club_brand_palette.dart';
import 'club_people_filter.dart';
import 'club_person_card.dart';

class ClubPeopleTab extends StatefulWidget {
  const ClubPeopleTab({
    super.key,
    required this.role,
    required this.people,
    required this.palette,
    required this.onPersonTap,
  });

  final String role;
  final List<SportPerson> people;
  final ClubBrandPalette palette;
  final ValueChanged<SportPerson> onPersonTap;

  @override
  State<ClubPeopleTab> createState() => _ClubPeopleTabState();
}

class _ClubPeopleTabState extends State<ClubPeopleTab>
    with AutomaticKeepAliveClientMixin {
  String _query = '';
  String? _group;
  ClubPeopleStatusFilter _status = ClubPeopleStatusFilter.all;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rolePeople = widget.people
        .where((person) => person.role == widget.role)
        .toList(growable: false);
    final filtered = filterClubPeople(
      rolePeople,
      query: _query,
      group: _group,
      status: _status,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${filtered.length} ${widget.role.toLowerCase()}',
                style: const TextStyle(
                  color: KokColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              key: ValueKey('club-people-filter-${widget.role}'),
              onPressed: () => _showFilters(rolePeople),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Filter'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final person in filtered) ...[
          ClubPersonCard(
            person: person,
            palette: widget.palette,
            onTap: () => widget.onPersonTap(person),
          ),
          const SizedBox(height: 10),
        ],
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Data milik SICABOR. Perubahan diajukan lewat pengurus klub — aplikasi ini tidak menyunting.',
            textAlign: TextAlign.center,
            style: TextStyle(color: KokColors.muted, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    );
  }

  Future<void> _showFilters(List<SportPerson> rolePeople) async {
    var draftQuery = _query;
    var draftGroup = _group;
    var draftStatus = _status;
    final groups = rolePeople.map((person) => person.group).toSet().toList()
      ..sort();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
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
                Text(
                  'Filter ${widget.role}',
                  style: const TextStyle(
                    color: KokColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('club-filter-query'),
                  initialValue: draftQuery,
                  onChanged: (value) => draftQuery = value,
                  decoration: const InputDecoration(
                    labelText: 'Cari nama',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                _FilterDropdown<String?>(
                  key: const ValueKey('club-filter-group'),
                  label: 'Kelompok',
                  value: draftGroup,
                  options: [
                    (null, 'Semua kelompok'),
                    for (final group in groups) (group, group),
                  ],
                  onChanged: (value) => setSheetState(() => draftGroup = value),
                ),
                const SizedBox(height: 12),
                _FilterDropdown<ClubPeopleStatusFilter>(
                  key: const ValueKey('club-filter-status'),
                  label: 'Status',
                  value: draftStatus,
                  options: const [
                    (ClubPeopleStatusFilter.all, 'Semua'),
                    (ClubPeopleStatusFilter.complete, 'Lengkap'),
                    (ClubPeopleStatusFilter.needsAttention, 'Perlu perhatian'),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => draftStatus = value),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          draftQuery = '';
                          draftGroup = null;
                          draftStatus = ClubPeopleStatusFilter.all;
                          setState(() {
                            _query = draftQuery;
                            _group = draftGroup;
                            _status = draftStatus;
                          });
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.palette.selectedTab,
                          foregroundColor: widget.palette.foreground,
                        ),
                        onPressed: () {
                          setState(() {
                            _query = draftQuery;
                            _group = draftGroup;
                            _status = draftStatus;
                          });
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Terapkan'),
                      ),
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

class _FilterDropdown<T> extends StatefulWidget {
  const _FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  State<_FilterDropdown<T>> createState() => _FilterDropdownState<T>();
}

class _FilterDropdownState<T> extends State<_FilterDropdown<T>> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = widget.options
        .firstWhere((option) => option.$1 == widget.value)
        .$2;
    return Semantics(
      button: true,
      expanded: _open,
      label: widget.label,
      value: selectedLabel,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _open = !_open),
            child: InputDecorator(
              decoration: InputDecoration(labelText: widget.label),
              child: Row(
                children: [
                  Expanded(child: Text(selectedLabel)),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            for (final option in widget.options)
              InkWell(
                onTap: () {
                  widget.onChanged(option.$1);
                  setState(() => _open = false);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(option.$2)),
                      if (option.$1 == widget.value)
                        const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: KokColors.blue,
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
