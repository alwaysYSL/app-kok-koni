import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models/athlete.dart';
import '../../data/providers/athlete_providers.dart';
import '../../shared/remote_error_presentation.dart';

const _scope = (idCabor: null, idClub: null);

class AthleteListPage extends ConsumerStatefulWidget {
  const AthleteListPage({super.key});

  @override
  ConsumerState<AthleteListPage> createState() => _AthleteListPageState();
}

class _AthleteListPageState extends ConsumerState<AthleteListPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(athletePaginationProvider(_scope).notifier).loadFirstPage();
      }
    });
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
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
        title: const Text('Daftar Atlet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final option in const [
                  (label: 'Semua gender', value: null),
                  (label: 'Laki-Laki', value: 'l'),
                  (label: 'Perempuan', value: 'p'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(option.label),
                      selected: state.sex == option.value,
                      onSelected: (_) =>
                          controller.updateSexFilter(option.value),
                    ),
                  ),
                const SizedBox(width: 8),
                for (final option in const [
                  (label: 'Semua status', value: null),
                  (label: 'Aktif', value: 1),
                  (label: 'Belum Aktif', value: 0),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(option.label),
                      selected: state.status == option.value,
                      onSelected: (_) =>
                          controller.updateStatusFilter(option.value),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              '${state.total} atlet',
              style: const TextStyle(
                color: KokColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
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
            ((state.isLoadingMore || state.loadMoreError != null) ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            if (state.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }
            return TextButton(
              onPressed: controller.loadMore,
              child: const Text('Gagal memuat atlet berikutnya · Coba lagi'),
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
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    color: Colors.white,
    child: InkWell(
      onTap: () => context.push('/person/${athlete.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    athlete.club?.name ?? 'Klub belum tercatat',
                    style: const TextStyle(
                      color: KokColors.muted,
                      fontSize: 12,
                    ),
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
      ),
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
