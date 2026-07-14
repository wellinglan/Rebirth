import 'health_entry.dart';
import 'health_save_data.dart';
import 'health_summary.dart';

abstract interface class HealthRepository {
  Future<HealthEntry> getToday();

  Future<HealthEntry?> getByDate(String recordDate);

  Future<List<HealthEntry>> listRecent({int days = 30});

  Future<List<HealthEntry>> listByDateRange({
    required String startDate,
    required String endDate,
  });

  Future<HealthEntry> saveForDate(HealthSaveData data);

  Future<HealthSummary> getSummary({int days = 7});
}
