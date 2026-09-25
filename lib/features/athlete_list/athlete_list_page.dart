import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models/athlete.dart';
import '../../data/providers/athlete_providers.dart';
import '../../shared/widgets.dart';

const _scope = (idCabor: null, idClub: null);

class AthleteListPage extends ConsumerStatefulWidget {
  const AthleteListPage({super.key});

  @override
  ConsumerState<AthleteListPage> createState() => _AthleteListPageState();
}

class _AthleteListPageState extends ConsumerState<AthleteListPage> {
  late final TextEditingController _search;
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: ref.read(athletePaginationProvider(_scope)).search ?? '',
    );
    Future.microtask(() {
      if (mounted) {
        ref.read(athletePaginationProvider(_scope).notifier).loadFirstPage();
      }
    });
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (ref.read(athletePaginationProvider(_scope)).loadMoreError != null) {
      return;
    }
    if (_scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      ref.read(athletePaginationProvider(_scope).notifier).loadMore();
    }
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref
            .read(athletePaginationProvider(_scope).notifier)
            .updateSearch(query);
      }
    });
    setState(() {});
  }

  Future<void> _showFilters(
    AthletePaginationState current,
    AthletePaginationController controller,
  ) async {
    String? draftSex = current.sex;
    int? draftStatus = current.status;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setDraft) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Atlet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Jenis kelamin',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in const [
                      (label: 'Semua', value: null),
                      (label: 'Laki-Laki', value: 'l'),
                      (label: 'Perempuan', value: 'p'),
                    ])
                      ChoiceChip(
                        label: Text(option.label),
                        selected: draftSex == option.value,
                        onSelected: (_) =>
                            setDraft(() => draftSex = option.value),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in const [
                      (label: 'Semua status', value: null),
                      (label: 'Aktif', value: 1),
                      (label: 'Belum Aktif', value: 0),
                    ])
                      ChoiceChip(
                        label: Text(option.label),
                        selected: draftStatus == option.value,
                        onSelected: (_) =>
                            setDraft(() => draftStatus = option.value),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setDraft(() {
                        draftSex = null;
                        draftStatus = null;
                      }),
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          controller.updateFilters(
                            sex: draftSex,
                            status: draftStatus,
                          );
                          Navigator.of(sheetContext).pop();
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

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(athletePaginationProvider(_scope));
    final controller = ref.read(athletePaginationProvider(_scope).notifier);

    return Scaffold(
      backgroundColor: KokColors.background,
      appBar: AppBar(
        title: const Text('Atlet'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: const ValueKey('athlete-search'),
              controller: _search,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Cari nama atau kode atlet',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _debounce?.cancel();
                          _search.clear();
                          controller.updateSearch(null);
                          setState(() {});
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: KokColors.borderGray),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${state.total} atlet',
                    style: const TextStyle(
                      color: KokColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showFilters(state, controller),
                  icon: Icon(
                    Icons.tune_rounded,
                    color: state.sex != null || state.status != null
                        ? KokColors.blue
                        : KokColors.muted,
                  ),
                  label: const Text('Filter'),
                ),
              ],
            ),
          ),
          if (state.hasFilterWarning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                state.filterWarningMessage ?? 'Sebagian filter tidak tersedia.',
                style: const TextStyle(color: KokColors.blue),
              ),
            ),
          Expanded(child: _body(state, controller)),
        ],
      ),
    );
  }

  Widget _body(
    AthletePaginationState state,
    AthletePaginationController controller,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (state.error != null && state.items.isEmpty) {
      final error = describeRemoteError(state.error!);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44, color: KokColors.red),
              const SizedBox(height: 12),
              const Text('Gagal memuat data atlet'),
              const SizedBox(height: 6),
              Text(error.message, textAlign: TextAlign.center),
              if (error.canRetry)
                TextButton(
                  onPressed: controller.loadFirstPage,
                  child: const Text('Coba Lagi'),
                ),
            ],
          ),
        ),
      );
    }
    if (state.items.isEmpty) {
      return const Center(child: Text('Tidak ada atlet yang sesuai filter.'));
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        key: const ValueKey('athlete-list'),
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount:
            state.items.length +
            ((state.isLoadingMore ||
                    state.loadMoreError != null ||
                    !state.hasMore)
                ? 1
                : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            if (state.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }
            if (state.loadMoreError == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    'Semua atlet telah ditampilkan',
                    style: TextStyle(color: KokColors.muted, fontSize: 12),
                  ),
                ),
              );
            }
            final error = describeRemoteError(state.loadMoreError!);
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(error.message, textAlign: TextAlign.center),
                  if (error.canRetry)
                    TextButton(
                      onPressed: controller.loadMore,
                      child: const Text('Coba Lagi'),
                    ),
                ],
              ),
            );
          }
          return _AthleteCard(athlete: state.items[index]);
        },
      ),
    );
  }
}

class _AthleteCard extends StatelessWidget {
  const _AthleteCard({required this.athlete});

  final Athlete athlete;

  @override
  Widget build(BuildContext context) => Surface(
    onTap: () => context.push('/person/${athlete.id}'),
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 44,
            height: 44,
            child: athlete.photoUrl.isEmpty
                ? _avatarFallback()
                : Image.network(
                    athlete.photoUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : _avatarFallback(),
                    errorBuilder: (_, _, _) => _avatarFallback(),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                athlete.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: KokColors.cardTitle,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                athlete.club?.name ?? 'Klub belum tercatat',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: KokColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (athlete.code.trim().isNotEmpty) _tag(athlete.code),
                  _tag(athlete.cabor.name),
                  if (athlete.statusLabel.trim().isNotEmpty)
                    _tag(athlete.statusLabel),
                ],
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: KokColors.muted),
      ],
    ),
  );

  Widget _avatarFallback() => ColoredBox(
    color: KokColors.pale,
    child: Center(
      child: Text(
        athlete.name.isEmpty ? 'A' : athlete.name[0].toUpperCase(),
        style: const TextStyle(
          color: KokColors.blue,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _tag(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: KokColors.pale,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(label, style: const TextStyle(fontSize: 10)),
  );
}
