import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/data/models.dart';

void main() {
  test('Club reads optional SICABOR branding fields', () {
    final club = Club.fromJson(const {
      'id': 'garuda',
      'name': 'Klub Garuda Muda',
      'sport': 'Sepak Bola',
      'village': 'Pakuwon',
      'logoUrl': 'https://example.test/garuda.png',
      'brandPrimaryHex': '#5B566E',
      'brandSecondaryHex': '#11294B',
      'foundedYear': 2011,
      'registrationNumber': 'SK 042/KONI/2023',
    });

    expect(club.logoUrl, 'https://example.test/garuda.png');
    expect(club.brandPrimaryHex, '#5B566E');
    expect(club.brandSecondaryHex, '#11294B');
    expect(club.foundedYear, 2011);
    expect(club.registrationNumber, 'SK 042/KONI/2023');
  });

  test('new branding and person fields remain optional', () {
    final club = Club.fromJson(const {
      'id': 'plain',
      'name': 'Klub Tanpa Branding',
      'sport': 'Lainnya',
      'village': 'Pakuwon',
    });
    final person = SportPerson.fromJson(const {
      'id': 'p1',
      'name': 'Nama Atlet',
      'clubId': 'plain',
      'role': 'Atlet',
      'group': 'U-18',
    });

    expect(club.logoUrl, isNull);
    expect(club.brandPrimaryHex, isNull);
    expect(club.foundedYear, isNull);
    expect(person.photoUrl, isNull);
    expect(person.gender, isNull);
    expect(person.age, isNull);
  });
}
