import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../shared/widgets.dart';

class ClubsPage extends StatefulWidget {
  const ClubsPage({super.key, this.sport});
  final String? sport;
  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends State<ClubsPage> {
  final _search = TextEditingController();
  String? _sport, _status, _village;
  bool _ascending = true;
  @override
  void initState() {
    super.initState();
    _sport = widget.sport;
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
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.sport ?? 'Klub'),
      actions: [
        IconButton(
          tooltip: 'Ubah urutan nama',
          icon: const Icon(Icons.swap_vert),
          onPressed: () => setState(() => _ascending = !_ascending),
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
          ascending: _ascending,
        );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari nama klub...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        onPressed: () => setState(_search.clear),
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(label: const Text('Reset'), onPressed: _reset),
                  const SizedBox(width: 8),
                  if (widget.sport == null)
                    FilterMenu(
                      label: 'Cabor',
                      value: _sport,
                      options: data.clubs.map((c) => c.sport).toSet().toList(),
                      onChanged: (v) => setState(() => _sport = v),
                    ),
                  FilterMenu(
                    label: 'Status',
                    value: _status,
                    options: const ['Aktif', 'Pasif'],
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  FilterMenu(
                    label: 'Kelurahan',
                    value: _village,
                    options: data.clubs.map((c) => c.village).toSet().toList(),
                    onChanged: (v) => setState(() => _village = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${clubs.length} klub · ${clubs.map((c) => c.sport).toSet().length} cabor',
                      style: const TextStyle(color: KokColors.muted),
                    ),
                  ),
                  Text(
                    _ascending ? 'A → Z' : 'Z → A',
                    style: const TextStyle(
                      color: KokColors.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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

class FilterMenu extends StatelessWidget {
  const FilterMenu({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: PopupMenuButton<String>(
      tooltip: 'Filter $label',
      initialValue: value ?? '',
      onSelected: (v) => onChanged(v.isEmpty ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem(value: '', child: Text('Semua $label')),
        ...options.map((o) => PopupMenuItem(value: o, child: Text(o))),
      ],
      child: Chip(
        backgroundColor: value == null ? Colors.white : KokColors.pale,
        label: Text(value ?? label),
        avatar: const Icon(Icons.keyboard_arrow_down, size: 18),
      ),
    ),
  );
}

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
    final missing = people.where((p) => p.missingDocuments.isNotEmpty).length;
    return Surface(
      onTap: () => context.push('/club/${club.id}'),
      child: Column(
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${club.sport} · ${compact ? '${people.where((p) => p.role == 'Atlet').length} atlet' : club.village}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: KokColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (compact)
                const Icon(Icons.chevron_right, color: KokColors.muted)
              else
                StatusBadge(club.active ? 'Aktif' : 'Pasif'),
            ],
          ),
          if (!compact) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${people.where((p) => p.role == 'Atlet').length} atlet · ${people.where((p) => p.role == 'Pelatih').length} pelatih · ${people.where((p) => p.role == 'Official').length} official',
                  style: const TextStyle(fontSize: 12, color: KokColors.muted),
                ),
                if (missing > 0) StatusBadge('$missing berkas', warning: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
