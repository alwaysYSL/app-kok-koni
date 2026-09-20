import '../models/profile_summary.dart';
import '../request_cancellation.dart';

abstract interface class ProfileService {
  Future<ProfileSummary> fetchProfileSummary({
    RequestCancellation? cancellation,
  });
}
