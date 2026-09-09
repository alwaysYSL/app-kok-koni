import 'package:flutter_test/flutter_test.dart';
import 'package:kok_app/core/config/app_environment.dart';

void main() {
  group('AppEnvironment Hardening Tests', () {
    test(
      'validateAppConfiguration melempar StateError saat production menggunakan demo auth atau data',
      () {
        expect(
          () => validateAppConfiguration(
            environment: AppEnvironment.production,
            usesDemoAuth: true,
            usesDemoData: false,
          ),
          throwsStateError,
        );

        expect(
          () => validateAppConfiguration(
            environment: AppEnvironment.production,
            usesDemoAuth: false,
            usesDemoData: true,
          ),
          throwsStateError,
        );
      },
    );

    test(
      'validateAppConfiguration lolos saat demo atau staging menggunakan demo auth',
      () {
        expect(
          () => validateAppConfiguration(
            environment: AppEnvironment.demo,
            usesDemoAuth: true,
            usesDemoData: true,
          ),
          returnsNormally,
        );

        expect(
          () => validateAppConfiguration(
            environment: AppEnvironment.staging,
            usesDemoAuth: true,
            usesDemoData: true,
          ),
          returnsNormally,
        );
      },
    );
  });
}
