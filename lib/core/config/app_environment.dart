enum AppEnvironment {
  demo,
  staging,
  production,
}

AppEnvironment get currentEnvironment {
  const envStr = String.fromEnvironment('APP_ENV', defaultValue: 'demo');
  return switch (envStr) {
    'production' => AppEnvironment.production,
    'staging' => AppEnvironment.staging,
    'demo' => AppEnvironment.demo,
    _ => throw StateError('Environment tidak dikenal: $envStr'),
  };
}

void validateAppConfiguration({
  required AppEnvironment environment,
  required bool usesDemoAuth,
  required bool usesDemoData,
}) {
  if (environment == AppEnvironment.production) {
    if (usesDemoAuth || usesDemoData) {
      throw StateError(
        'FATAL: Konfigurasi produksi ditolak! Build produksi dilarang keras menggunakan kredensial/adapter demo.',
      );
    }
  }
}
