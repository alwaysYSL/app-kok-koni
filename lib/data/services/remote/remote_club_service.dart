import '../../../core/network/api_client.dart';
import '../../dto/sicabor_club_detail_item.dart';
import '../../dto/sicabor_club_item.dart';
import '../../dto/sicabor_detail_envelope.dart';
import '../../dto/sicabor_list_envelope.dart';
import '../../mapper/sicabor_data_mapper.dart';
import '../../models/club.dart';
import '../../models/club_detail.dart';
import '../../models/paginated_result.dart';
import '../../request_cancellation.dart';
import '../club_service.dart';

final class RemoteClubService implements ClubService {
  RemoteClubService({
    required this.client,
    this.mapper = const SicaborDataMapper(),
  });

  final ApiClient client;
  final SicaborDataMapper mapper;

  @override
  Future<PaginatedResult<Club>> fetchClubList({
    int limit = 25,
    int offset = 0,
    int? idCabor,
    int? status,
    String? search,
    String sort = 'name',
    RequestCancellation? cancellation,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'sort': sort,
    };
    if (idCabor != null) queryParams['id_cabor'] = idCabor;
    if (status != null) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await client.request<dynamic>(
      '/club',
      method: 'GET',
      queryParameters: queryParams,
      cancellation: cancellation,
    );

    final data = response.data;
    final map = data is Map<String, dynamic>
        ? data
        : (data as Map).cast<String, dynamic>();

    final envelope = SicaborListEnvelope<SicaborClubItem>.fromJson(
      map,
      SicaborClubItem.fromJson,
    );

    final clubList = envelope.data.map(mapper.mapClub).toList();

    final rawFilterWarning = envelope.meta.extra['filter_warning'];
    final filterWarning = rawFilterWarning is Map<String, dynamic>
        ? rawFilterWarning
        : rawFilterWarning is Map
        ? rawFilterWarning.cast<String, dynamic>()
        : null;

    return PaginatedResult<Club>(
      items: clubList,
      limit: envelope.meta.limit,
      offset: envelope.meta.offset,
      total: envelope.meta.total,
      filterWarning: filterWarning,
    );
  }

  @override
  Future<ClubDetail> fetchClubDetail(
    int id, {
    RequestCancellation? cancellation,
  }) async {
    final response = await client.request<dynamic>(
      '/club/detail/$id',
      method: 'GET',
      cancellation: cancellation,
    );

    final data = response.data;
    final map = data is Map<String, dynamic>
        ? data
        : (data as Map).cast<String, dynamic>();

    final envelope = SicaborDetailEnvelope<SicaborClubDetailItem>.fromJson(
      map,
      SicaborClubDetailItem.fromJson,
    );

    return mapper.mapClubDetail(envelope.data);
  }
}
