import '../models/athlete.dart';
import '../models/athlete_detail.dart';
import '../models/paginated_result.dart';
import '../request_cancellation.dart';

abstract interface class AthleteService {
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
  });

  Future<AthleteDetail> fetchAthleteDetail(
    int id, {
    RequestCancellation? cancellation,
  });
}
