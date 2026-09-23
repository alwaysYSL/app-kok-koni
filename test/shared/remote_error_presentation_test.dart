import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/network/api_exceptions.dart';
import 'package:kok_app/shared/remote_error_presentation.dart';

void main() {
  group('describeRemoteError', () {
    test(
      'ForbiddenException with NO_SUBDISTRICT errorCode appends hubungi admin',
      () {
        const error = ForbiddenException(
          'Akun tidak memiliki kecamatan',
          'NO_SUBDISTRICT',
          'Akun tidak terikat pada kecamatan manapun.',
        );
        final presentation = describeRemoteError(error);
        expect(
          presentation.message,
          equals(
            'Akun tidak terikat pada kecamatan manapun. Hubungi admin kabupaten.',
          ),
        );
        expect(presentation.canRetry, isFalse);
      },
    );

    test(
      'ForbiddenException with NO_SUBDISTRICT fallback to exception message',
      () {
        const error = ForbiddenException(
          'Akses ditolak',
          'NO_SUBDISTRICT',
          null,
        );
        final presentation = describeRemoteError(error);
        expect(
          presentation.message,
          equals('Akses ditolak Hubungi admin kabupaten.'),
        );
        expect(presentation.canRetry, isFalse);
      },
    );

    test(
      'ForbiddenException with other error code returns serverMessage or message with canRetry=false',
      () {
        const error1 = ForbiddenException(
          'Akses ditolak',
          'MEMBER_INACTIVE',
          'Akun anggota tidak aktif.',
        );
        final presentation1 = describeRemoteError(error1);
        expect(presentation1.message, equals('Akun anggota tidak aktif.'));
        expect(presentation1.canRetry, isFalse);

        const error2 = ForbiddenException('Akses ditolak', 'SOME_CODE', null);
        final presentation2 = describeRemoteError(error2);
        expect(presentation2.message, equals('Akses ditolak'));
        expect(presentation2.canRetry, isFalse);
      },
    );

    test('ApiTimeoutException returns friendly message and canRetry=true', () {
      const error = ApiTimeoutException();
      final presentation = describeRemoteError(error);
      expect(presentation.message, equals('Koneksi ke server terganggu.'));
      expect(presentation.canRetry, isTrue);
    });

    test(
      'NetworkOfflineException returns friendly message and canRetry=true',
      () {
        const error = NetworkOfflineException();
        final presentation = describeRemoteError(error);
        expect(presentation.message, equals('Koneksi ke server terganggu.'));
        expect(presentation.canRetry, isTrue);
      },
    );

    test('ServerErrorException returns friendly message and canRetry=true', () {
      const error = ServerErrorException('Server internal error');
      final presentation = describeRemoteError(error);
      expect(presentation.message, equals('Koneksi ke server terganggu.'));
      expect(presentation.canRetry, isTrue);
    });

    test('ApiConfigurationException returns message and canRetry=false', () {
      const error = ApiConfigurationException('Base URL tidak valid');
      final presentation = describeRemoteError(error);
      expect(presentation.message, equals('Base URL tidak valid'));
      expect(presentation.canRetry, isFalse);
    });

    test('NotFoundException returns message and canRetry=false', () {
      const error = NotFoundException('Data klub tidak ditemukan');
      final presentation = describeRemoteError(error);
      expect(presentation.message, equals('Data klub tidak ditemukan'));
      expect(presentation.canRetry, isFalse);
    });

    test('Generic ApiException returns message and canRetry=true', () {
      const error = BadRequestException('Format request tidak sesuai');
      final presentation = describeRemoteError(error);
      expect(presentation.message, equals('Format request tidak sesuai'));
      expect(presentation.canRetry, isTrue);
    });

    test(
      'Other Object/Exception returns default message and canRetry=true',
      () {
        final error = Exception('Unknown database error');
        final presentation = describeRemoteError(error);
        expect(presentation.message, equals('Gagal memuat data.'));
        expect(presentation.canRetry, isTrue);
      },
    );
  });
}
