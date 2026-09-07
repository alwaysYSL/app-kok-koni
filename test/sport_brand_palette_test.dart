import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/features/sport_detail/sport_brand_palette.dart';

void main() {
  group('SportBrandPaletteResolver', () {
    test('resolves distinct palettes for known sports', () {
      final silat = SportBrandPaletteResolver.resolve('Pencak Silat');
      final badminton = SportBrandPaletteResolver.resolve('Bulu Tangkis');
      final football = SportBrandPaletteResolver.resolve('Sepak Bola');
      final volleyball = SportBrandPaletteResolver.resolve('Bola Voli');
      final swimming = SportBrandPaletteResolver.resolve('Renang');

      expect(silat.headerStart, const Color(0xFFC2410C));
      expect(badminton.headerStart, const Color(0xFF6D28D9));
      expect(football.headerStart, const Color(0xFF1D4ED8));
      expect(volleyball.headerStart, const Color(0xFF0284C7));
      expect(swimming.headerStart, const Color(0xFF0F766E));
    });

    test('resolves fallback palette for unknown sport', () {
      final unknown = SportBrandPaletteResolver.resolve('Olahraga Lain');
      expect(unknown.headerStart, const Color(0xFF1B4FA0));
      expect(unknown.headerEnd, const Color(0xFF123A75));
    });
  });
}
