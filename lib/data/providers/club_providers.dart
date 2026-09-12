import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kok_repository.dart';
import '../models.dart';
import '../request_cancellation.dart';
import 'snapshot_provider.dart';

@visibleForTesting
Future<T> runGranularRequest<T>(
  Ref ref,
  Future<T> Function(
    RequestCancellation cancellation,
    DataRequestContext context,
  ) request,
) async {
  final context = ref.watch(dataRequestContextProvider);
  if (context == null) {
    throw const SessionRequiredException();
  }

  final cancellationController = RequestCancellationController();
  ref.onDispose(() => cancellationController.cancel('Provider disposed'));

  final result = await request(cancellationController.token, context);
  cancellationController.token.throwIfCancelled();

  if (!ref.mounted || ref.read(dataRequestContextProvider) != context) {
    throw const RequestCancelledException('Stale granular response rejected');
  }

  return result;
}

@visibleForTesting
Duration? granularRetry(int retryCount, Object error) {
  if (error is SessionRequiredException ||
      error is RequestCancelledException ||
      error is UnsupportedScopeException ||
      error is KokResourceNotFoundException) {
    return null;
  }
  return ProviderContainer.defaultRetry(retryCount, error);
}

final clubDetailProvider = FutureProvider.family<Club, String>((ref, clubId) {
  return runGranularRequest(
    ref,
    (cancellation, _) => ref
        .read(repositoryProvider)
        .fetchClubDetail(clubId, cancellation: cancellation),
  );
}, retry: granularRetry);

final clubMembersProvider =
    FutureProvider.family<List<SportPerson>, ({String clubId, String? role})>((
      ref,
      params,
    ) {
      return runGranularRequest(
        ref,
        (cancellation, _) => ref
            .read(repositoryProvider)
            .fetchClubMembers(
              params.clubId,
              role: params.role,
              cancellation: cancellation,
            ),
      );
    }, retry: granularRetry);

final personDetailProvider = FutureProvider.family<SportPerson, String>((
  ref,
  personId,
) {
  return runGranularRequest(
    ref,
    (cancellation, _) => ref
        .read(repositoryProvider)
        .fetchPersonDetail(personId, cancellation: cancellation),
  );
}, retry: granularRetry);

final committeeProvider = FutureProvider<List<CommitteeMember>>((ref) {
  return runGranularRequest(
    ref,
    (cancellation, context) => ref
        .read(repositoryProvider)
        .fetchCommittee(context.scope, cancellation: cancellation),
  );
}, retry: granularRetry);

final helpdeskProvider = FutureProvider<HelpdeskContact?>((ref) {
  return runGranularRequest(
    ref,
    (cancellation, _) =>
        ref.read(repositoryProvider).fetchHelpdesk(cancellation: cancellation),
  );
}, retry: granularRetry);

