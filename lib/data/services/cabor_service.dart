import '../models/cabor.dart';
import '../models/paginated_result.dart';
import '../request_cancellation.dart';

abstract interface class CaborService {
  Future<PaginatedResult<Cabor>> fetchCaborList({
    int limit = 25,
    int offset = 0,
    String source = 'all',
    String sort = 'name',
    RequestCancellation? cancellation,
  });
}
