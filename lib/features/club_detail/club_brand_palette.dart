import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';

@immutable
class ClubBrandPalette {
  const ClubBrandPalette({
    required this.headerStart,
    required this.headerEnd,
    required this.foreground,
    required this.selectedTab,
    required this.softAccent,
    required this.fallbackAvatar,
  });

  final Color headerStart;
  final Color headerEnd;
  final Color foreground;
  final Color selectedTab;
  final Color softAccent;
  final Color fallbackAvatar;
}

abstract final class ClubBrandPaletteResolver {
  static const Map<String, (Color, Color)> _demoPalettes = {
    'garuda': (Color(0xFF5B566E), Color(0xFF11294B)),
    'pb': (Color(0xFFA51D2A), Color(0xFF670A13)),
    'voli': (Color(0xFFF3B51B), Color(0xFF8F6100)),
  };

  static Color? tryParseHex(String? value) {
    if (value == null) return null;
    var digits = value.trim();
    if (digits.startsWith('#')) digits = digits.substring(1);
    if (digits.length == 6) digits = 'FF$digits';
    if (digits.length != 8) return null;
    final parsed = int.tryParse(digits, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  static ClubBrandPalette resolve(Club club) {
    final explicitStart = tryParseHex(club.brandPrimaryHex);
    final explicitEnd = tryParseHex(club.brandSecondaryHex);
    final fallback = _demoPalettes[club.id] ?? _sportPalette(club.sport);
    final start = _opaque(explicitStart ?? fallback.$1);
    final end = _opaque(
      explicitEnd ??
          (explicitStart == null ? fallback.$2 : _darken(start, 0.24)),
    );
    final safePair = _ensureHeaderPair(start, end);
    final selectedTab = _ensureContrast(safePair.$2, safePair.$3);
    return ClubBrandPalette(
      headerStart: safePair.$1,
      headerEnd: safePair.$2,
      foreground: safePair.$3,
      selectedTab: selectedTab,
      softAccent: Color.alphaBlend(
        safePair.$1.withValues(alpha: .12),
        Colors.white,
      ),
      fallbackAvatar: Color.alphaBlend(
        safePair.$3.withValues(alpha: .16),
        safePair.$1,
      ),
    );
  }

  static (Color, Color) _sportPalette(String sport) => switch (sport) {
    'Sepak Bola' => (const Color(0xFF315A91), const Color(0xFF17345C)),
    'Bulu Tangkis' => (const Color(0xFF51478A), const Color(0xFF2F285D)),
    'Pencak Silat' => (const Color(0xFFA23A2B), const Color(0xFF642117)),
    'Voli' => (const Color(0xFFC88B08), const Color(0xFF795000)),
    'Renang' => (const Color(0xFF168A91), const Color(0xFF07555E)),
    _ => (KokColors.blue, KokColors.navy),
  };

  static Color _opaque(Color color) => color.withValues(alpha: 1);

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  static double _contrastRatio(Color a, Color b) {
    final aLum = a.computeLuminance();
    final bLum = b.computeLuminance();
    final lighter = aLum > bLum ? aLum : bLum;
    final darker = aLum > bLum ? bLum : aLum;
    return (lighter + 0.05) / (darker + 0.05);
  }

  static (Color, Color, Color) _ensureHeaderPair(Color start, Color end) {
    const darkInk = Color(0xFF17191D);
    double minimum(Color foreground) =>
        _minimumGradientContrast(foreground, start, end);

    final whiteMinimum = minimum(Colors.white);
    final darkMinimum = minimum(darkInk);
    if (whiteMinimum >= 4.5 || darkMinimum >= 4.5) {
      return whiteMinimum >= darkMinimum
          ? (start, end, Colors.white)
          : (start, end, darkInk);
    }

    var safeStart = start;
    var safeEnd = end;
    for (var i = 0; i < 12; i++) {
      safeStart = _darken(safeStart, 0.035);
      safeEnd = _darken(safeEnd, 0.035);
      if (_minimumGradientContrast(Colors.white, safeStart, safeEnd) >= 4.5) {
        break;
      }
    }
    if (_minimumGradientContrast(Colors.white, safeStart, safeEnd) < 4.5) {
      safeStart = safeEnd = Colors.black;
    }
    return (safeStart, safeEnd, Colors.white);
  }

  static double _minimumGradientContrast(
    Color foreground,
    Color start,
    Color end,
  ) {
    var minimum = double.infinity;
    for (var step = 0; step <= 8; step++) {
      final ratio = _contrastRatio(
        foreground,
        Color.lerp(start, end, step / 8)!,
      );
      if (ratio < minimum) minimum = ratio;
    }
    return minimum;
  }

  static Color _ensureContrast(Color background, Color foreground) {
    var result = background;
    for (var i = 0; i < 12 && _contrastRatio(result, foreground) < 4.5; i++) {
      result = foreground == Colors.white
          ? _darken(result, 0.035)
          : _lighten(result, 0.035);
    }
    if (_contrastRatio(result, foreground) >= 4.5) return result;
    return foreground == Colors.white ? Colors.black : Colors.white;
  }
}
