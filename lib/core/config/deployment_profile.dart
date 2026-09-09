enum AppEnv { demo, staging, production }

enum AuthMode { demo, remote }

enum DataMode { demo, remote }

final class DeploymentProfile {
  const DeploymentProfile({
    required this.environment,
    required this.authMode,
    required this.dataMode,
  });

  final AppEnv environment;
  final AuthMode authMode;
  final DataMode dataMode;

  static DeploymentProfile fromEnvironment() {
    const envStr = String.fromEnvironment('APP_ENV', defaultValue: 'demo');
    const authStr = String.fromEnvironment('AUTH_MODE', defaultValue: 'demo');
    const dataStr = String.fromEnvironment('DATA_MODE', defaultValue: 'demo');

    final env = switch (envStr) {
      'production' => AppEnv.production,
      'staging' => AppEnv.staging,
      'demo' => AppEnv.demo,
      _ => throw StateError('APP_ENV tidak dikenal: $envStr'),
    };
    final auth = switch (authStr) {
      'remote' => AuthMode.remote,
      'demo' => AuthMode.demo,
      _ => throw StateError('AUTH_MODE tidak dikenal: $authStr'),
    };
    final data = switch (dataStr) {
      'remote' => DataMode.remote,
      'demo' => DataMode.demo,
      _ => throw StateError('DATA_MODE tidak dikenal: $dataStr'),
    };

    final profile = DeploymentProfile(
      environment: env,
      authMode: auth,
      dataMode: data,
    );
    profile.validate();
    return profile;
  }

  void validate() {
    if (environment == AppEnv.demo) {
      if (authMode != AuthMode.demo || dataMode != DataMode.demo) {
        throw StateError(
          'Environment demo hanya mendukung auth demo dan data demo.',
        );
      }
    } else if (environment == AppEnv.staging) {
      if (authMode == AuthMode.demo && dataMode == DataMode.remote) {
        throw StateError(
          'Staging menolak kombinasi auth demo dengan data remote.',
        );
      }
    } else if (environment == AppEnv.production) {
      if (authMode != AuthMode.remote || dataMode != DataMode.remote) {
        throw StateError(
          'Production wajib menggunakan auth remote dan data remote.',
        );
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeploymentProfile &&
          runtimeType == other.runtimeType &&
          environment == other.environment &&
          authMode == other.authMode &&
          dataMode == other.dataMode;

  @override
  int get hashCode => Object.hash(environment, authMode, dataMode);

  @override
  String toString() =>
      'DeploymentProfile(environment: $environment, authMode: $authMode, dataMode: $dataMode)';
}
