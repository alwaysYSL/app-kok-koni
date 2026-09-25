import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/features/sport_detail/sport_brand_palette.dart';

void main() {
  group('SportBrandPaletteResolver', () {
    test('uses the KOK blue palette for every sport', () {
      final silat = SportBrandPaletteResolver.resolve('Pencak Silat');
      final badminton = SportBrandPaletteResolver.resolve('Bulu Tangkis');
      final football = SportBrandPaletteResolver.resolve('Sepak Bola');
      final volleyball = SportBrandPaletteResolver.resolve('Bola Voli');
      final swimming = SportBrandPaletteResolver.resolve('Renang');

      for (final palette in [
        silat,
        badminton,
        football,
        volleyball,
        swimming,
      ]) {
        expect(palette.headerStart, const Color(0xFF1B4F9E));
        expect(palette.headerEnd, const Color(0xFF123A75));
        expect(palette.chartColor, const Color(0xFF1B4F9E));
      }
    });

    test('resolves fallback palette for unknown sport', () {
      final unknown = SportBrandPaletteResolver.resolve('Olahraga Lain');
      expect(unknown.headerStart, const Color(0xFF1B4F9E));
      expect(unknown.headerEnd, const Color(0xFF123A75));
    });
  });
}
