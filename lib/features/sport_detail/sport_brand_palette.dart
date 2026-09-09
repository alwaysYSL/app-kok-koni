import 'package:flutter/material.dart';

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

class SportBrandPaletteResolver {
  static const _silat = SportBrandPalette(
    headerStart: Color(0xFFC2410C),
    headerEnd: Color(0xFF9A3412),
    softAccent: Color(0xFFFFEDD5),
    badgeBackground: Color(0xFFFFF7ED),
    chartColor: Color(0xFFEA580C),
  );

  static const _badminton = SportBrandPalette(
    headerStart: Color(0xFF6D28D9),
    headerEnd: Color(0xFF4C1D95),
    softAccent: Color(0xFFDDD6FE),
    badgeBackground: Color(0xFFF5F3FF),
    chartColor: Color(0xFF7C3AED),
  );

  static const _football = SportBrandPalette(
    headerStart: Color(0xFF1D4ED8),
    headerEnd: Color(0xFF1E3A8A),
    softAccent: Color(0xFFDBEAFE),
    badgeBackground: Color(0xFFEFF6FF),
    chartColor: Color(0xFF2563EB),
  );

  static const _volleyball = SportBrandPalette(
    headerStart: Color(0xFF0284C7),
    headerEnd: Color(0xFF0369A1),
    softAccent: Color(0xFFE0F2FE),
    badgeBackground: Color(0xFFF0F9FF),
    chartColor: Color(0xFF0284C7),
  );

  static const _swimming = SportBrandPalette(
    headerStart: Color(0xFF0F766E),
    headerEnd: Color(0xFF115E59),
    softAccent: Color(0xFFCCFBF1),
    badgeBackground: Color(0xFFF0FDFA),
    chartColor: Color(0xFF0D9488),
  );

  static const _fallback = SportBrandPalette(
    headerStart: Color(0xFF1B4FA0),
    headerEnd: Color(0xFF123A75),
    softAccent: Color(0xFFE9F0FB),
    badgeBackground: Color(0xFFF0F4FA),
    chartColor: Color(0xFF1B4FA0),
  );

  static SportBrandPalette resolve(String sport) {
    final lower = sport.toLowerCase();
    if (lower.contains('silat')) return _silat;
    if (lower.contains('tangkis') || lower.contains('badminton')) {
      return _badminton;
    }
    if (lower.contains('sepak') ||
        lower.contains('bola') && !lower.contains('voli')) {
      return _football;
    }
    if (lower.contains('voli')) return _volleyball;
    if (lower.contains('renang')) return _swimming;
    return _fallback;
  }
}
