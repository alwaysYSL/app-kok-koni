import 'package:flutter/material.dart';

import '../../core/theme.dart';

class SportBrandPalette {
  const SportBrandPalette({
    required this.headerStart,
    required this.headerEnd,
    required this.softAccent,
    required this.badgeBackground,
    required this.chartColor,
  });

  final Color headerStart;
  final Color headerEnd;
  final Color softAccent;
  final Color badgeBackground;
  final Color chartColor;
}

abstract final class SportBrandPaletteResolver {
  static const _kok = SportBrandPalette(
    headerStart: KokColors.blue,
    headerEnd: Color(0xFF123A75),
    softAccent: KokColors.pale,
    badgeBackground: Color(0xFFF0F4FA),
    chartColor: KokColors.blue,
  );

  static SportBrandPalette resolve(String sport) => _kok;
}
