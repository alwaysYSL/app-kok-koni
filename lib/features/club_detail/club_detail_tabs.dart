import 'package:flutter/material.dart';

import '../../shared/collapsing_detail_header.dart';
import 'club_brand_palette.dart';

class ClubDetailTabBar extends StatelessWidget {
  const ClubDetailTabBar({super.key, required this.palette});

  final ClubBrandPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14071B68),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: TabBar(
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: palette.selectedTab,
        borderRadius: BorderRadius.circular(14),
      ),
      labelColor: palette.foreground,
      unselectedLabelColor: const Color(0xFF666A73),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      tabs: const [
        Tab(text: 'Atlet'),
        Tab(text: 'Pelatih'),
        Tab(text: 'Official'),
        Tab(text: 'Dokumen'),
      ],
    ),
  );
}

class ClubDetailRemoteTabBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ClubDetailRemoteTabBar({super.key, required this.palette});

  final ClubBrandPalette palette;

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) => DetailPillTabBar(
    labels: const ['Info', 'Pengurus', 'Atlet'],
    selectedColor: palette.selectedTab,
    selectedForeground: palette.foreground,
  );
}
