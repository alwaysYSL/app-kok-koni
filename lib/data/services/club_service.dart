import '../models/club.dart';
import '../models/club_detail.dart';
import '../models/paginated_result.dart';
import '../request_cancellation.dart';

abstract interface class ClubService {
  Future<PaginatedResult<Club>> fetchClubList({
    int limit = 25,
    int offset = 0,
    int? idCabor,
    int? status,
    String? search,
    String sort = 'name',
    RequestCancellation? cancellation,
  });

  Future<ClubDetail> fetchClubDetail(
    int id, {
    RequestCancellation? cancellation,
  });
}
