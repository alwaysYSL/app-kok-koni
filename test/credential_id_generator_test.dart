import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/auth/domain/credential_id_generator.dart';

void main() {
  group('CredentialIdGenerator Tests', () {
    group('UuidCredentialIdGenerator', () {
      final generator = UuidCredentialIdGenerator();
      final uuidV4Regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );

      test('menghasilkan UUID sesuai spesifikasi RFC 4122 v4', () {
        final id = generator.generate();
        expect(id, matches(uuidV4Regex));
      });

      test('menghasilkan ID unik dan valid pada pemanggilan beruntun', () {
        final generated = <String>{};
        const count = 100;

        for (var i = 0; i < count; i++) {
          final id = generator.generate();
          expect(id, matches(uuidV4Regex));
          generated.add(id);
        }

        expect(generated.length, equals(count));
      });
    });

    group('DeterministicCredentialIdGenerator', () {
      test('menggunakan prefix default "cred" dan sekuens 1, 2, 3', () {
        final generator = DeterministicCredentialIdGenerator();
        expect(generator.generate(), equals('cred-1'));
        expect(generator.generate(), equals('cred-2'));
        expect(generator.generate(), equals('cred-3'));
      });

      test('mendukung custom prefix dengan sekuens independen', () {
        final generator = DeterministicCredentialIdGenerator('session');
        expect(generator.generate(), equals('session-1'));
        expect(generator.generate(), equals('session-2'));
      });

      test('mengimplementasikan interface CredentialIdGenerator', () {
        final CredentialIdGenerator generator =
            DeterministicCredentialIdGenerator('mock');
        expect(generator.generate(), equals('mock-1'));
      });
    });
  });
}
