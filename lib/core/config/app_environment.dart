import 'deployment_profile.dart';

export 'deployment_profile.dart' show AppEnv;

typedef AppEnvironment = AppEnv;

AppEnvironment get currentEnvironment {
  final profile = DeploymentProfile.fromEnvironment();
  return profile.environment;
}

void validateAppConfiguration({
  required AppEnvironment environment,
  required bool usesDemoAuth,
  required bool usesDemoData,
}) {
  final authMode = usesDemoAuth ? AuthMode.demo : AuthMode.remote;
  final dataMode = usesDemoData ? DataMode.demo : DataMode.remote;
  final profile = DeploymentProfile(
    environment: environment,
    authMode: authMode,
    dataMode: dataMode,
  );
  profile.validate();
}
