import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/composition/app_composition.dart';
import '../core/config/deployment_profile.dart';
import '../core/theme.dart';
import '../data/club_filters.dart';
import '../data/models.dart';
import '../data/models/club.dart' as domain;
import '../data/providers/club_providers.dart';
import '../data/providers/snapshot_provider.dart';
import '../shared/widgets.dart';

bool _isRemoteMode(WidgetRef ref) {
  try {
    return ref.watch(appCompositionProvider).profile.dataMode ==
        DataMode.remote;
  } catch (_) {
    return false;
  }
}

class ClubsPage extends ConsumerStatefulWidget {
  const ClubsPage({super.key, this.sport});
  final String? sport;
  @override
  ConsumerState<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends ConsumerState<ClubsPage> {
  final _search = TextEditingController();
  final _remoteSearch = TextEditingController();
  final _remoteScrollController = ScrollController();
  Timer? _remoteDebounceTimer;

  String? _sport, _status, _village;
  ClubSortOption _sortOption = ClubSortOption.nameAsc;

  static const _remoteStatusFilterOptions = [
    (label: 'Semua', value: null),
    (label: 'Aktif', value: 1),
    (label: 'Belum Aktif', value: 0),
  ];

  @override
  void initState() {
    super.initState();
    _sport = widget.sport;
    Future.microtask(() {
      if (mounted && _isRemoteMode(ref)) {
        ref.read(clubPaginationProvider(null).notifier).loadFirstPage();
      }
    });
    _remoteScrollController.addListener(_onRemoteScroll);
  }

  void _onRemoteScroll() {
    if (_remoteScrollController.hasClients &&
        _remoteScrollController.position.pixels >=
            _remoteScrollController.position.maxScrollExtent - 200) {
      ref.read(clubPaginationProvider(null).notifier).loadMore();
    }
  }

  void _onRemoteSearchChanged(String query) {
    _remoteDebounceTimer?.cancel();
    _remoteDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(clubPaginationProvider(null).notifier).updateSearch(query);
      }
    });
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
    _remoteDebounceTimer?.cancel();
    _remoteScrollController.dispose();
    _remoteSearch.dispose();
    _search.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _search.clear();
    _sport = widget.sport;
    _status = null;
    _village = null;
  });

  void _showRemoteSortModal(
    BuildContext context,
    ClubPaginationState state,
    ClubPaginationController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        final options = [
          ('name', 'Nama (A → Z)'),
          ('code', 'Kode Klub'),
          ('since', 'Tahun Berdiri'),
          ('status', 'Status'),
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
                  final isSelected = state.sort == opt.$1;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      controller.updateSort(opt.$1);
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
    if (_isRemoteMode(ref)) {
      final state = ref.watch(clubPaginationProvider(null));
      final controller = ref.read(clubPaginationProvider(null).notifier);

      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Klub',
            style: TextStyle(
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
                    onTap: () =>
                        _showRemoteSortModal(context, state, controller),
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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TextField(
                  controller: _remoteSearch,
                  onChanged: (val) {
                    setState(() {});
                    _onRemoteSearchChanged(val);
                  },
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
                    suffixIcon: _remoteSearch.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              _remoteDebounceTimer?.cancel();
                              _remoteSearch.clear();
                              controller.updateSearch(null);
                              setState(() {});
                            },
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
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _remoteStatusFilterOptions.map((opt) {
                  final isSelected = state.status == opt.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(opt.label),
                      selected: isSelected,
                      onSelected: (_) =>
                          controller.updateStatusFilter(opt.value),
                      selectedColor: KokColors.pale,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? KokColors.blue
                            : const Color(0xFF17191D),
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? KokColors.blue
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (state.hasFilterWarning)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF2563EB),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.filterWarningMessage ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!state.isLoading && state.error == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  '${state.total} klub ditemukan',
                  style: const TextStyle(
                    fontSize: 13,
                    color: KokColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Expanded(child: _buildRemoteBody(context, state, controller)),
          ],
        ),
      );
    }

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

  Widget _buildRemoteBody(
    BuildContext context,
    ClubPaginationState state,
    ClubPaginationController controller,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (state.error != null && state.items.isEmpty) {
      final presentation = describeRemoteError(state.error!);
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: KokColors.red),
              const SizedBox(height: 12),
              const Text(
                'Gagal memuat data klub',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: KokColors.cardTitle,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                presentation.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: KokColors.muted),
              ),
              if (presentation.canRetry) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => controller.loadFirstPage(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: EmptyState(
            message: 'Tidak ada klub yang sesuai dengan filter.',
            onReset: () {
              _remoteDebounceTimer?.cancel();
              _remoteSearch.clear();
              controller.updateSearch(null);
              controller.updateStatusFilter(null);
              controller.updateSort('name');
              setState(() {});
            },
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.refresh(),
      child: ListView.builder(
        controller: _remoteScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount:
            state.items.length +
            (state.isLoadingMore || state.loadMoreError != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            if (state.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }
            if (state.loadMoreError != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      const Text(
                        'Gagal memuat klub berikutnya',
                        style: TextStyle(fontSize: 12, color: KokColors.muted),
                      ),
                      TextButton(
                        onPressed: () => controller.loadMore(),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          final club = state.items[index];
          return _buildRemoteClubCard(context, club);
        },
      ),
    );
  }

  Widget _buildRemoteClubCard(BuildContext context, domain.Club club) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Surface(
        onTap: () => context.push('/club/${club.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: KokColors.pale,
                  backgroundImage:
                      (club.logoUrl != null && club.logoUrl!.isNotEmpty)
                      ? NetworkImage(club.logoUrl!)
                      : null,
                  child: (club.logoUrl == null || club.logoUrl!.isEmpty)
                      ? Text(
                          club.name.isNotEmpty ? club.name[0] : 'K',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: KokColors.blue,
                          ),
                        )
                      : null,
                ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (club.headName != null &&
                          club.headName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Ketua: ${club.headName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: KokColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (club.secretariat.address != null &&
                          club.secretariat.address!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Sekretariat: ${club.secretariat.address!}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: KokColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else if (club
                          .secretariat
                          .subdistrictName
                          .isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Sekretariat: Kec. ${club.secretariat.subdistrictName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: KokColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: KokColors.muted,
                  size: 20,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: DashedDivider(color: Color(0xFFE5E7EB)),
            ),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: KokColors.pale,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          club.cabor.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: KokColors.blue,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: club.status == 1
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          club.statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: club.status == 1
                                ? const Color(0xFF16A34A)
                                : KokColors.textSecondary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${club.totalAthleteInClub} atlet terdaftar di klub',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: KokColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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
