enum AppEnv { demo, staging, production }

enum AuthMode { demo, remote }

enum DataMode { demo, remote }

final class DeploymentProfile {
  const DeploymentProfile({
    required this.environment,
    required this.authMode,
    required this.dataMode,
    this.apiBaseUrl = '',
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 30),
  });

  final AppEnv environment;
  final AuthMode authMode;
  final DataMode dataMode;
  final String apiBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  static DeploymentProfile fromEnvironment() {
    const envStr = String.fromEnvironment('APP_ENV', defaultValue: 'demo');
    const authStr = String.fromEnvironment('AUTH_MODE', defaultValue: 'demo');
    const dataStr = String.fromEnvironment('DATA_MODE', defaultValue: 'demo');
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const connectTimeoutMs = String.fromEnvironment('API_CONNECT_TIMEOUT_MS');
    const receiveTimeoutMs = String.fromEnvironment('API_RECEIVE_TIMEOUT_MS');

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

    Duration parseTimeout(String name, String raw, Duration fallback) {
      if (raw.isEmpty) return fallback;
      final milliseconds = int.tryParse(raw);
      if (milliseconds == null || milliseconds <= 0) {
        throw StateError(
          '$name harus berupa bilangan positif dalam milidetik.',
        );
      }
      return Duration(milliseconds: milliseconds);
    }

    final profile = DeploymentProfile(
      environment: env,
      authMode: auth,
      dataMode: data,
      apiBaseUrl: apiBaseUrl,
      connectTimeout: parseTimeout(
        'API_CONNECT_TIMEOUT_MS',
        connectTimeoutMs,
        const Duration(seconds: 10),
      ),
      receiveTimeout: parseTimeout(
        'API_RECEIVE_TIMEOUT_MS',
        receiveTimeoutMs,
        const Duration(seconds: 30),
      ),
    );
    profile.validate();
    return profile;
  }

  void validate() {
    if (connectTimeout <= Duration.zero || receiveTimeout <= Duration.zero) {
      throw StateError('Timeout API harus lebih besar dari nol.');
    }

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

    if (authMode == AuthMode.remote || dataMode == DataMode.remote) {
      final uri = Uri.tryParse(apiBaseUrl);
      if (uri == null ||
          uri.host.isEmpty ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        throw StateError(
          'API_BASE_URL wajib berupa URL absolut http/https untuk mode remote.',
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
          dataMode == other.dataMode &&
          apiBaseUrl == other.apiBaseUrl &&
          connectTimeout == other.connectTimeout &&
          receiveTimeout == other.receiveTimeout;

  @override
  int get hashCode => Object.hash(
    environment,
    authMode,
    dataMode,
    apiBaseUrl,
    connectTimeout,
    receiveTimeout,
  );

  @override
  String toString() =>
      'DeploymentProfile(environment: $environment, authMode: $authMode, dataMode: $dataMode, apiBaseUrl: $apiBaseUrl, connectTimeout: $connectTimeout, receiveTimeout: $receiveTimeout)';
}
