import 'sync_entity_type.dart';
import 'sync_models.dart';

abstract interface class SyncConflictPayloadCodec {
  SyncEntityType get entityType;

  Map<String, Object?> encode(SyncEntityPayload payload);

  SyncEntityPayload decode({
    required String recordId,
    required Map<String, Object?> json,
  });
}
