import '../../../core/auth/data/dto/sicabor_profile_response.dart';
import '../../../core/network/api_client.dart';
import '../../mapper/sicabor_data_mapper.dart';
import '../../models/profile_summary.dart';
import '../../request_cancellation.dart';
import '../profile_service.dart';

final class RemoteProfileService implements ProfileService {
  RemoteProfileService({
    required this.client,
    this.mapper = const SicaborDataMapper(),
  });

  final ApiClient client;
  final SicaborDataMapper mapper;

  @override
  Future<ProfileSummary> fetchProfileSummary({
    RequestCancellation? cancellation,
  }) async {
    final response = await client.request<dynamic>(
      '/profile',
      method: 'GET',
      cancellation: cancellation,
    );

    final data = response.data;
    final map = data is Map<String, dynamic>
        ? data
        : (data as Map).cast<String, dynamic>();

    final dto = SicaborProfileResponse.fromJson(map);
    return mapper.mapProfileSummary(dto);
  }
}
