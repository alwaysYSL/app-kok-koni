import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/domain/auth_state.dart';
import '../../core/auth/domain/user_principal.dart';
import '../../core/auth/presentation/auth_controller.dart';
import '../../core/composition/app_composition.dart';
import '../demo_kok_repository.dart';
import '../kok_repository.dart';
import '../models.dart';
import '../request_cancellation.dart';

final class SessionRequiredException implements Exception {
  final String message;
  const SessionRequiredException([
    this.message =
        'Sesi terautentikasi aktif dibutuhkan untuk mengakses data keolahragaan.',
  ]);

  @override
  String toString() => message;
}

final class DataRequestContext {
  const DataRequestContext({
    required this.environment,
    required this.userId,
    required this.scope,
    required this.generation,
  });

  final AppEnv environment;
  final String userId;
  final AccessScope scope;
  final int generation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataRequestContext &&
          environment == other.environment &&
          userId == other.userId &&
          scope == other.scope &&
          generation == other.generation;

  @override
  int get hashCode => Object.hash(environment, userId, scope, generation);
}

final repositoryProvider = Provider<KokRepository>((ref) {
  final composition = ref.watch(appCompositionProvider);
  if (composition != null) {
    return composition.kokRepository;
  }
  return DemoKokRepository();
});

final dataRequestContextProvider = Provider<DataRequestContext?>((ref) {
  final authState = ref.watch(authControllerProvider);
  if (authState is AuthSignedIn) {
    final composition = ref.watch(appCompositionProvider);
    final env =
        composition?.profile.environment ??
        DeploymentProfile.fromEnvironment().environment;
    return DataRequestContext(
      environment: env,
      userId: authState.user.id,
      scope: authState.user.scope,
      generation: authState.generation,
    );
  }
  return null;
});

final snapshotProvider = FutureProvider<KokSnapshot>(
  (ref) async {
    final initialContext = ref.watch(dataRequestContextProvider);
    if (initialContext == null) {
      throw const SessionRequiredException();
    }

    final repository = ref.watch(repositoryProvider);
    final cancellationController = RequestCancellationController();
    ref.onDispose(() => cancellationController.cancel('Provider disposed'));

    final snapshot = await repository.fetchScope(
      initialContext.scope,
      cancellation: cancellationController.token,
    );

    cancellationController.token.throwIfCancelled();

    final currentContext = ref.read(dataRequestContextProvider);
    if (currentContext != initialContext) {
      throw const RequestCancelledException(
        'Stale cross-session response rejected',
      );
    }

    return snapshot;
  },
  retry: (retryCount, error) {
    if (error is SessionRequiredException ||
        error is RequestCancelledException ||
        error is UnsupportedScopeException) {
      return null;
    }
    return ProviderContainer.defaultRetry(retryCount, error);
  },
);
