import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../club_detail/club_brand_palette.dart';

enum SearchCategory {
  all('Semua'),
  athletes('Atlet'),
  coaches('Pelatih'),
  clubs('Klub'),
  sports('Cabor');

  const SearchCategory(this.label);
  final String label;
}

class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  SearchCategory _selectedCategory = SearchCategory.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KokColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
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
              context.go('/home');
            }
          },
        ),
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14.5, color: KokColors.cardTitle),
            decoration: InputDecoration(
              hintText: 'Cari nama atlet, pelatih, klub, cabor...',
              hintStyle: const TextStyle(color: KokColors.muted, fontSize: 13.5),
              prefixIcon: const Icon(Icons.search, size: 20, color: KokColors.muted),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18, color: KokColors.muted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onChanged: (val) => setState(() => _query = val.trim()),
          ),
        ),
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      body: DataView(
        builder: (data) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCategoryChips(),
              Expanded(
                child: _query.isEmpty
                    ? _buildInitialState(data)
                    : _buildSearchResults(data),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: SearchCategory.values.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(cat.label),
                selected: isSelected,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : KokColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
                selectedColor: KokColors.bluePrimary,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected ? KokColors.bluePrimary : const Color(0xFFE5E7EB),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                showCheckmark: false,
                onSelected: (_) => setState(() => _selectedCategory = cat),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInitialState(KokSnapshot data) {
    final sports = data.clubs.map((c) => c.sport).toSet().take(6).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        const Center(
          child: Icon(Icons.manage_search_rounded, size: 48, color: KokColors.blueMedium),
        ),
        const SizedBox(height: 12),
        const Text(
          'Pencarian Terpadu Garut Kota',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: KokColors.cardTitle,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ketik nama atlet, pelatih, klub, atau cabang olahraga untuk menemukan data secara cepat.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: KokColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 24),
        const Text(
          'SARAN CABANG OLAHRAGA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: KokColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sports.map((sport) {
            return ActionChip(
              avatar: Icon(sportIcon(sport), size: 16, color: KokColors.bluePrimary),
              label: Text(sport),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: KokColors.cardTitle,
              ),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onPressed: () {
                _searchController.text = sport;
                setState(() => _query = sport);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults(KokSnapshot data) {
    final q = _query.toLowerCase();

    // 1. Match Athletes & Coaches
    final matchedPeople = data.people.where((p) {
      final club = data.clubs.firstWhere(
        (c) => c.id == p.clubId,
        orElse: () => Club(id: p.clubId, name: '', sport: '', village: ''),
      );

      final matchesText = p.name.toLowerCase().contains(q) ||
          club.name.toLowerCase().contains(q) ||
          club.sport.toLowerCase().contains(q) ||
          p.group.toLowerCase().contains(q);

      if (!matchesText) return false;

      return switch (_selectedCategory) {
        SearchCategory.all => true,
        SearchCategory.athletes => p.role == 'Atlet',
        SearchCategory.coaches => p.role == 'Pelatih',
        _ => false,
      };
    }).toList();

    // 2. Match Clubs
    final matchedClubs = switch (_selectedCategory) {
      SearchCategory.all || SearchCategory.clubs => data.clubs.where((c) {
          return c.name.toLowerCase().contains(q) ||
              c.sport.toLowerCase().contains(q) ||
              c.village.toLowerCase().contains(q);
        }).toList(),
      _ => <Club>[],
    };

    // 3. Match Sports
    final allSports = data.clubs.map((c) => c.sport).toSet().toList();
    final matchedSports = switch (_selectedCategory) {
      SearchCategory.all || SearchCategory.sports => allSports.where((s) {
          return s.toLowerCase().contains(q);
        }).toList(),
      _ => <String>[],
    };

    final totalCount = matchedPeople.length + matchedClubs.length + matchedSports.length;

    if (totalCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 52, color: KokColors.muted),
              const SizedBox(height: 12),
              Text(
                'Tidak ditemukan hasil untuk "$_query"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: KokColors.cardTitle,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Coba gunakan kata kunci lain atau periksa filter kategori di atas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: KokColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DITEMUKAN $totalCount HASIL',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: KokColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...matchedClubs.map((c) {
          final athletesCount = data.people.where((p) => p.clubId == c.id && p.role == 'Atlet').length;
          return _buildClubResultCard(c, athletesCount);
        }),
        ...matchedSports.map((s) {
          final clubsCount = data.clubs.where((c) => c.sport == s).length;
          final athletesCount = data.people.where((p) {
            final club = data.clubs.firstWhere(
              (c) => c.id == p.clubId,
              orElse: () => Club(id: p.clubId, name: '', sport: '', village: ''),
            );
            return club.sport == s && p.role == 'Atlet';
          }).length;
          return _buildSportResultCard(s, clubsCount, athletesCount);
        }),
        ...matchedPeople.map((p) {
          final club = data.clubs.firstWhere(
            (c) => c.id == p.clubId,
            orElse: () => Club(id: p.clubId, name: 'Klub', sport: '', village: ''),
          );
          final palette = ClubBrandPaletteResolver.resolve(club);
          return _buildPersonResultCard(p, club, palette);
        }),
      ],
    );
  }

  Widget _buildPersonResultCard(SportPerson person, Club club, ClubBrandPalette palette) {
    final isAthlete = person.role == 'Atlet';
    final roleBg = isAthlete ? const Color(0xFFD1FAE5) : const Color(0xFFE0E7FF);
    final roleFg = isAthlete ? const Color(0xFF059669) : const Color(0xFF3730A3);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/person/${person.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.fallbackAvatar,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.headerStart.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.headerStart,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: KokColors.cardTitle,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            person.role,
                            style: TextStyle(
                              color: roleFg,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${club.name} · ${club.sport} (${person.group})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: KokColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: KokColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClubResultCard(Club club, int athleteCount) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/club/${club.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KokColors.pale,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(sportIcon(club.sport), size: 22, color: KokColors.bluePrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: KokColors.cardTitle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${club.sport} · ${club.village} · $athleteCount atlet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: KokColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: KokColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSportResultCard(String sport, int clubsCount, int athletesCount) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/sport/${Uri.encodeComponent(sport)}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(sportIcon(sport), size: 22, color: KokColors.bluePrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sport,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: KokColors.cardTitle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$clubsCount klub · $athletesCount atlet terdaftar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: KokColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: KokColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
