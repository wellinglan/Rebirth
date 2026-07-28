import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';

abstract interface class JournalConflictResolutionService {
  Future<void> requestAdoptRemote({
    required SyncConflictScope scope,
    required String conflictId,
  });

  Future<void> requestKeepLocal({
    required SyncConflictScope scope,
    required String conflictId,
  });
}
