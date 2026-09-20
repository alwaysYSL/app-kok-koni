import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/composition/app_composition.dart';
import '../models/profile_summary.dart';
import '../providers/snapshot_provider.dart';
import '../request_cancellation.dart';
import '../services/profile_service.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  final composition = ref.watch(appCompositionProvider);
  return (composition as dynamic).profileService as ProfileService;
});

final profileSummaryProvider = FutureProvider<ProfileSummary>((ref) async {
  final initialContext = ref.watch(dataRequestContextProvider);
  if (initialContext == null) {
    throw const RequestCancelledException(
      'Sesi tidak aktif atau telah berakhir.',
    );
  }

  final service = ref.watch(profileServiceProvider);
  final cancellationController = RequestCancellationController();
  ref.onDispose(() => cancellationController.cancel('Provider disposed'));

  final summary = await service.fetchProfileSummary(
    cancellation: cancellationController.token,
  );

  cancellationController.token.throwIfCancelled();

  final currentContext = ref.read(dataRequestContextProvider);
  if (!ref.mounted || currentContext != initialContext) {
    throw const RequestCancelledException(
      'Konteks sesi berubah saat memuat ringkasan.',
    );
  }

  return summary;
}, retry: (retryCount, error) => null);
