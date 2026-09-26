import 'package:flutter/material.dart';

import '../core/theme.dart';

/// One scrolling surface for a detail hero, its compact title, and pinned tabs.
class CollapsingDetailHeader extends SliverPersistentHeaderDelegate {
  CollapsingDetailHeader({
    required this.hero,
    required this.heroHeight,
    required this.topInset,
    required this.title,
    required this.headerColor,
    required this.foregroundColor,
    required this.tabs,
    required this.onBack,
    required this.compactHeaderKey,
    this.onShare,
    this.shareTooltip,
  });

  final Widget hero;
  final double heroHeight;
  final double topInset;
  final String title;
  final Color headerColor;
  final Color foregroundColor;
  final Widget tabs;
  final VoidCallback onBack;
  final Key compactHeaderKey;
  final VoidCallback? onShare;
  final String? shareTooltip;

  static const double tabHeight = 80;
  static const double toolbarHeight = 58;

  @override
  double get minExtent => topInset + toolbarHeight + tabHeight;

  @override
  double get maxExtent => heroHeight + tabHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final travel = maxExtent - minExtent;
    final progress = travel <= 0
        ? 1.0
        : (shrinkOffset / travel).clamp(0.0, 1.0);
    final titleOpacity = ((progress - 0.55) / 0.45).clamp(0.0, 1.0);

    return ClipRect(
      child: ColoredBox(
        color: headerColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -shrinkOffset,
              left: 0,
              right: 0,
              height: heroHeight,
              child: hero,
            ),
            if (titleOpacity > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: tabHeight,
                height: topInset + toolbarHeight,
                child: IgnorePointer(
                  ignoring: titleOpacity < 0.9,
                  child: Opacity(
                    opacity: titleOpacity,
                    child: ColoredBox(
                      key: compactHeaderKey,
                      color: headerColor,
                      child: Padding(
                        padding: EdgeInsets.only(top: topInset),
                        child: Transform.translate(
                          offset: Offset(0, (1 - titleOpacity) * 8),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Kembali',
                                onPressed: onBack,
                                color: foregroundColor,
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: foregroundColor,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (onShare != null)
                                IconButton(
                                  tooltip: shareTooltip,
                                  onPressed: onShare,
                                  color: foregroundColor,
                                  icon: const Icon(Icons.share_outlined),
                                )
                              else
                                const SizedBox(width: 48),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: tabHeight,
              child: DecoratedBox(
                key: const Key('detail-header-lip'),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(KokRadii.contentTop),
                  ),
                ),
                child: tabs,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant CollapsingDetailHeader oldDelegate) => true;
}

class DetailPillTabBar extends StatelessWidget implements PreferredSizeWidget {
  const DetailPillTabBar({
    super.key,
    required this.labels,
    required this.selectedColor,
    required this.selectedForeground,
  });

  final List<String> labels;
  final Color selectedColor;
  final Color selectedForeground;

  @override
  Size get preferredSize => const Size.fromHeight(80);

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
        color: selectedColor,
        borderRadius: BorderRadius.circular(14),
      ),
      labelColor: selectedForeground,
      unselectedLabelColor: const Color(0xFF666A73),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      tabs: [for (final label in labels) Tab(text: label)],
    ),
  );
}
