import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/data/models.dart';
import 'package:kok_app/features/club_detail/club_brand_palette.dart';

double contrast(Color a, Color b) {
  final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

Club club({
  String id = 'custom',
  String sport = 'Sepak Bola',
  String? primary,
  String? secondary,
}) => Club(
  id: id,
  name: 'Klub Test',
  sport: sport,
  village: 'Pakuwon',
  brandPrimaryHex: primary,
  brandSecondaryHex: secondary,
);

void main() {
  test('parses RGB and ARGB hex safely', () {
    expect(
      ClubBrandPaletteResolver.tryParseHex('#5B566E'),
      const Color(0xFF5B566E),
    );
    expect(
      ClubBrandPaletteResolver.tryParseHex('FF11294B'),
      const Color(0xFF11294B),
    );
    expect(
      ClubBrandPaletteResolver.tryParseHex('00112233'),
      const Color(0x00112233),
    );
    expect(ClubBrandPaletteResolver.tryParseHex('not-a-color'), isNull);
    expect(ClubBrandPaletteResolver.tryParseHex(null), isNull);
  });

  test('rejects hashes outside the optional leading position', () {
    expect(ClubBrandPaletteResolver.tryParseHex('12#3456'), isNull);
    expect(ClubBrandPaletteResolver.tryParseHex('#12#3456'), isNull);
  });

  test('explicit club colors win over demo and sport fallbacks', () {
    final palette = ClubBrandPaletteResolver.resolve(
      club(id: 'garuda', primary: '#123456', secondary: '#102030'),
    );
    expect(palette.headerStart, const Color(0xFF123456));
    expect(palette.headerEnd, const Color(0xFF102030));
  });

  test('demo clubs resolve to distinct palettes', () {
    final garuda = ClubBrandPaletteResolver.resolve(club(id: 'garuda'));
    final pb = ClubBrandPaletteResolver.resolve(club(id: 'pb'));
    final voli = ClubBrandPaletteResolver.resolve(club(id: 'voli'));
    expect({garuda.headerStart, pb.headerStart, voli.headerStart}.length, 3);
  });

  test('foreground remains readable for bright amber', () {
    final palette = ClubBrandPaletteResolver.resolve(
      club(primary: '#FFC21C', secondary: '#D08A00'),
    );
    expect(
      contrast(palette.foreground, palette.headerStart),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.foreground, palette.headerEnd),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.foreground, palette.selectedTab),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('forces a readable shared foreground for white and black endpoints', () {
    final palette = ClubBrandPaletteResolver.resolve(
      club(primary: '#FFFFFF', secondary: '#000000'),
    );
    expect(
      contrast(palette.foreground, palette.headerStart),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.foreground, palette.headerEnd),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(palette.foreground, palette.selectedTab),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('foreground remains readable through the middle of the gradient', () {
    final palette = ClubBrandPaletteResolver.resolve(
      club(primary: '#FF5500', secondary: '#00AA55'),
    );
    final middle = Color.lerp(palette.headerStart, palette.headerEnd, 0.5)!;

    expect(contrast(palette.foreground, middle), greaterThanOrEqualTo(4.5));
  });

  test('uses both configured fallback endpoints', () {
    final demo = ClubBrandPaletteResolver.resolve(club(id: 'garuda'));
    final sport = ClubBrandPaletteResolver.resolve(
      club(id: 'unknown-football'),
    );
    final defaults = ClubBrandPaletteResolver.resolve(
      club(id: 'unknown', sport: 'Panahan'),
    );

    expect(demo.headerStart, const Color(0xFF5B566E));
    expect(demo.headerEnd, const Color(0xFF11294B));
    expect(sport.headerStart, const Color(0xFF315A91));
    expect(sport.headerEnd, const Color(0xFF17345C));
    expect(defaults.headerStart, const Color(0xFF1B4F9E));
    expect(defaults.headerEnd, const Color(0xFF071B68));
  });

  test('normalizes resolved ARGB colors to opaque surfaces', () {
    expect(
      ClubBrandPaletteResolver.tryParseHex('00112233'),
      const Color(0x00112233),
    );

    final palette = ClubBrandPaletteResolver.resolve(
      club(primary: '00112233', secondary: '80123456'),
    );
    expect(palette.headerStart.toARGB32() >>> 24, 0xFF);
    expect(palette.headerEnd.toARGB32() >>> 24, 0xFF);
    expect(palette.selectedTab.toARGB32() >>> 24, 0xFF);
  });
}
