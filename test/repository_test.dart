import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kok_app/core/session.dart';
import 'package:kok_app/data/repository.dart';
import 'package:kok_app/data/models.dart';

void main() {
  test('Combined filters, sort and empty results', () async {
    final data = await DemoKokRepository().fetch();
    expect(
      filterClubs(
        data.clubs,
        query: ' GARUDA ',
        sport: 'Sepak Bola',
        status: 'Aktif',
        village: 'Pakuwon',
      ).single.id,
      'garuda',
    );
    expect(filterClubs(data.clubs, sport: 'Renang', status: 'Aktif'), isEmpty);
    expect(filterClubs(data.clubs, status: 'Pasif').single.id, 'tirta');
    expect(
      filterClubs(data.clubs, ascending: false).first,
      filterClubs(data.clubs).last,
    );
  });

  test('JSON round-trip and all people reference a known club', () async {
    final data = await DemoKokRepository().fetch();
    // Exercise nested JSON models and timestamps.
    final result = KokSnapshot.fromJson(data.toJson());
    expect(result, data);
    expect(
      data.people.every((p) => data.clubs.any((c) => c.id == p.clubId)),
      isTrue,
    );
    expect(data.people.where((p) => p.missingDocuments.isNotEmpty).length, 8);
    expect(data.people.where((p) => p.expiredLicense).length, 5);
  });

  test(
    'Reject invalid login; remember only SK; logout revokes session',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [preferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final session = container.read(sessionProvider.notifier);
      expect(await session.signIn('DEMO-001', 'wrong', true), isFalse);
      expect(container.read(sessionProvider), isFalse);
      expect(await session.signIn('DEMO-001', 'kokgarut123', true), isTrue);
      expect(prefs.getKeys(), {'remembered_sk'});
      session.signOut();
      expect(container.read(sessionProvider), isFalse);
      expect(await session.signIn('DEMO-001', 'kokgarut123', false), isTrue);
      expect(prefs.getKeys(), isEmpty);
    },
  );
}
