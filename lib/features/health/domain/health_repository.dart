import 'health_entry.dart';
import 'health_save_data.dart';
import 'health_summary.dart';

final class HealthRecordNotFoundException implements Exception {
  const HealthRecordNotFoundException(this.id);

  final String id;
}

final class HealthConflictPendingException implements Exception {
  const HealthConflictPendingException(this.id);

  final String id;
}

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

  Future<void> softDelete(String id);
}
