import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../../shared/widgets.dart';
import '../detail_pages.dart';
import 'club_brand_palette.dart';
import 'club_detail_header.dart';
import 'club_detail_tabs.dart';
import 'club_document_tab.dart';
import 'club_people_filter.dart';
import 'club_people_tab.dart';

class ClubDetailPage extends StatelessWidget {
  const ClubDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => DataView(
    builder: (data) {
      final matches = data.clubs.where((club) => club.id == id);
      if (matches.isEmpty) return const MissingPage();
      final club = matches.first;
      final allPeople = clubPeople(data, id);
      final athletes = allPeople.where((p) => p.role == 'Atlet').toList();
      final coaches = allPeople.where((p) => p.role == 'Pelatih').toList();
      final officials = allPeople.where((p) => p.role == 'Official').toList();
      final missingCount = allPeople.where(personNeedsAttention).length;
      final palette = ClubBrandPaletteResolver.resolve(club);

      return DefaultTabController(
        length: 4,
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
                sliver: SliverAppBar(
                  automaticallyImplyLeading: false,
                  pinned: true,
                  expandedHeight: 500,
                  toolbarHeight: 64,
                  backgroundColor: palette.headerEnd,
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      final titleOpacity =
                          ((500 - constraints.biggest.height) / 290).clamp(
                            0.0,
                            1.0,
                          );
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          FlexibleSpaceBar(
                            collapseMode: CollapseMode.parallax,
                            background: OverflowBox(
                              alignment: Alignment.topCenter,
                              maxHeight: double.infinity,
                              child: ClubDetailHeader(
                                club: club,
                                palette: palette,
                                athleteCount: athletes.length,
                                coachCount: coaches.length,
                                officialCount: officials.length,
                                missingFileCount: missingCount,
                                onBack: () => context.pop(),
                                onShare: () => _shareClub(context, club),
                              ),
                            ),
                          ),
                          if (titleOpacity > 0)
                            IgnorePointer(
                              child: Opacity(
                                opacity: titleOpacity,
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      64,
                                      20,
                                      64,
                                      0,
                                    ),
                                    child: Text(
                                      club.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.foreground,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(88),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF4F6FA),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: ClubDetailTabBar(palette: palette),
                    ),
                  ),
                ),
              ),
            ],
            // The absorbed pinned toolbar and tab panel have a fixed extent.
            body: Padding(
              padding: const EdgeInsets.only(top: 64 + 88),
              child: TabBarView(
                children: [
                  ClubPeopleTab(
                    role: 'Atlet',
                    people: athletes,
                    palette: palette,
                    onPersonTap: (person) =>
                        context.push('/person/${person.id}'),
                  ),
                  ClubPeopleTab(
                    role: 'Pelatih',
                    people: coaches,
                    palette: palette,
                    onPersonTap: (person) =>
                        context.push('/person/${person.id}'),
                  ),
                  ClubPeopleTab(
                    role: 'Official',
                    people: officials,
                    palette: palette,
                    onPersonTap: (person) =>
                        context.push('/person/${person.id}'),
                  ),
                  ClubDocumentTab(club: club),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Future<void> _shareClub(BuildContext context, Club club) async {
    await Clipboard.setData(
      ClipboardData(
        text: '${club.name} · ${club.sport} · Kel. ${club.village}',
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Info klub disalin')));
  }
}
