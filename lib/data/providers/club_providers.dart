import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kok_repository.dart';
import '../models.dart';
import '../request_cancellation.dart';
import 'snapshot_provider.dart';

Future<T> _runGranularRequest<T>(
  Ref ref,
  Future<T> Function(RequestCancellation cancellation) request,
) async {
  final context = ref.watch(dataRequestContextProvider);
  if (context == null) {
    throw const SessionRequiredException();
  }

  final cancellationController = RequestCancellationController();
  ref.onDispose(() => cancellationController.cancel('Provider disposed'));

  final result = await request(cancellationController.token);
  cancellationController.token.throwIfCancelled();

  if (ref.read(dataRequestContextProvider) != context) {
    throw const RequestCancelledException('Stale granular response rejected');
  }

  return result;
}

Duration? _granularRetry(int retryCount, Object error) {
  if (error is SessionRequiredException ||
      error is RequestCancelledException ||
      error is UnsupportedScopeException ||
      error is KokResourceNotFoundException) {
    return null;
  }
  return ProviderContainer.defaultRetry(retryCount, error);
}

final clubDetailProvider = FutureProvider.family<Club, String>((ref, clubId) {
  return _runGranularRequest(
    ref,
    (cancellation) => ref
        .read(repositoryProvider)
        .fetchClubDetail(clubId, cancellation: cancellation),
  );
}, retry: _granularRetry);

final clubMembersProvider =
    FutureProvider.family<List<SportPerson>, ({String clubId, String? role})>((
      ref,
      params,
    ) {
      return _runGranularRequest(
        ref,
        (cancellation) => ref
            .read(repositoryProvider)
            .fetchClubMembers(
              params.clubId,
              role: params.role,
              cancellation: cancellation,
            ),
      );
    }, retry: _granularRetry);

final personDetailProvider = FutureProvider.family<SportPerson, String>((
  ref,
  personId,
) {
  return _runGranularRequest(
    ref,
    (cancellation) => ref
        .read(repositoryProvider)
        .fetchPersonDetail(personId, cancellation: cancellation),
  );
}, retry: _granularRetry);

final committeeProvider = FutureProvider<List<CommitteeMember>>((ref) {
  return _runGranularRequest(ref, (cancellation) {
    final context = ref.read(dataRequestContextProvider);
    return ref
        .read(repositoryProvider)
        .fetchCommittee(context!.scope, cancellation: cancellation);
  });
}, retry: _granularRetry);

final helpdeskProvider = FutureProvider<HelpdeskContact?>((ref) {
  return _runGranularRequest(
    ref,
    (cancellation) =>
        ref.read(repositoryProvider).fetchHelpdesk(cancellation: cancellation),
  );
}, retry: _granularRetry);
