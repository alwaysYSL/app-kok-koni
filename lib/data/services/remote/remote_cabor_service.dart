import '../../../core/network/api_client.dart';
import '../../dto/sicabor_cabor_item.dart';
import '../../dto/sicabor_list_envelope.dart';
import '../../mapper/sicabor_data_mapper.dart';
import '../../models/cabor.dart';
import '../../models/paginated_result.dart';
import '../../request_cancellation.dart';
import '../cabor_service.dart';

final class RemoteCaborService implements CaborService {
  RemoteCaborService({
    required this.client,
    this.mapper = const SicaborDataMapper(),
  });

  final ApiClient client;
  final SicaborDataMapper mapper;

  @override
  Future<PaginatedResult<Cabor>> fetchCaborList({
    int limit = 25,
    int offset = 0,
    String source = 'all',
    String sort = 'name',
    RequestCancellation? cancellation,
  }) async {
    final response = await client.request<dynamic>(
      '/cabor',
      method: 'GET',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'source': source,
        'sort': sort,
      },
      cancellation: cancellation,
    );

    final data = response.data;
    final map = data is Map<String, dynamic>
        ? data
        : (data as Map).cast<String, dynamic>();

    final envelope = SicaborListEnvelope<SicaborCaborItem>.fromJson(
      map,
      SicaborCaborItem.fromJson,
    );

    final caborList = envelope.data.map(mapper.mapCabor).toList();

    return PaginatedResult<Cabor>(
      items: caborList,
      limit: envelope.meta.limit,
      offset: envelope.meta.offset,
      total: envelope.meta.total,
    );
  }
}
