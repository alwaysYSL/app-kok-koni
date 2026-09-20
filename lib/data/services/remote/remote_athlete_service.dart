import '../../../core/network/api_client.dart';
import '../../dto/sicabor_athlete_detail_item.dart';
import '../../dto/sicabor_athlete_item.dart';
import '../../dto/sicabor_detail_envelope.dart';
import '../../dto/sicabor_list_envelope.dart';
import '../../mapper/sicabor_data_mapper.dart';
import '../../models/athlete.dart';
import '../../models/athlete_detail.dart';
import '../../models/paginated_result.dart';
import '../../request_cancellation.dart';
import '../athlete_service.dart';

final class RemoteAthleteService implements AthleteService {
  RemoteAthleteService({
    required this.client,
    this.mapper = const SicaborDataMapper(),
  });

  final ApiClient client;
  final SicaborDataMapper mapper;

  @override
  Future<PaginatedResult<Athlete>> fetchAthleteList({
    int limit = 25,
    int offset = 0,
    int? idCabor,
    int? idClub,
    String? sex,
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
    if (idClub != null) queryParams['id_club'] = idClub;
    if (sex != null) queryParams['sex'] = sex;
    if (status != null) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await client.request<dynamic>(
      '/athlete',
      method: 'GET',
      queryParameters: queryParams,
      cancellation: cancellation,
    );

    final data = response.data;
    final map = data is Map<String, dynamic>
        ? data
        : (data as Map).cast<String, dynamic>();

    final envelope = SicaborListEnvelope<SicaborAthleteItem>.fromJson(
      map,
      SicaborAthleteItem.fromJson,
    );

    final athleteList = envelope.data.map(mapper.mapAthlete).toList();

    final rawFilterWarning = envelope.meta.extra['filter_warning'];
    final filterWarning = rawFilterWarning is Map<String, dynamic>
        ? rawFilterWarning
        : rawFilterWarning is Map
        ? rawFilterWarning.cast<String, dynamic>()
        : null;

    return PaginatedResult<Athlete>(
      items: athleteList,
      limit: envelope.meta.limit,
      offset: envelope.meta.offset,
      total: envelope.meta.total,
      filterWarning: filterWarning,
    );
  }

  @override
  Future<AthleteDetail> fetchAthleteDetail(
    int id, {
    RequestCancellation? cancellation,
  }) async {
    final response = await client.request<dynamic>(
      '/athlete/detail/$id',
      method: 'GET',
      cancellation: cancellation,
    );

    final data = response.data;
    final map = data is Map<String, dynamic>
        ? data
        : (data as Map).cast<String, dynamic>();

    final envelope = SicaborDetailEnvelope<SicaborAthleteDetailItem>.fromJson(
      map,
      SicaborAthleteDetailItem.fromJson,
    );

    return mapper.mapAthleteDetail(envelope.data);
  }
}
