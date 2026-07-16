import 'growth_period.dart';
import 'growth_snapshot.dart';

abstract interface class GrowthRepository {
  Future<GrowthSnapshot> loadRecent(GrowthPeriod period);
}
