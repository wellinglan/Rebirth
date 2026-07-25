import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_payload_codec.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

final class PlanSyncPayloadCodec implements SyncConflictPayloadCodec {
  const PlanSyncPayloadCodec([this._dateTimeService = const DateTimeService()]);

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final DateTimeService _dateTimeService;

  @override
  SyncEntityType get entityType => SyncEntityType.plan;

  @override
  Map<String, Object?> encode(SyncEntityPayload payload) {
    if (payload is! PlanSyncPayload) {
      throw const SyncException('Plan 同步 payload 类型无效。');
    }
    return {
      'parent_goal_id': payload.parentGoalId,
      'title': payload.title,
      'description': payload.description,
      'goal_level': payload.goalLevel.databaseValue,
      'status': payload.status.databaseValue,
      'start_date': payload.startDate,
      'target_date': payload.targetDate,
      'completed_at': payload.completedAt,
      'archived_at': payload.archivedAt,
      'sort_order': payload.sortOrder,
      'created_at': payload.createdAt,
    };
  }

  @override
  PlanSyncPayload decode({
    required String recordId,
    required Map<String, Object?> json,
  }) {
    const requiredKeys = [
      'parent_goal_id',
      'title',
      'description',
      'goal_level',
      'status',
      'start_date',
      'target_date',
      'completed_at',
      'archived_at',
      'sort_order',
      'created_at',
    ];
    for (final key in requiredKeys) {
      if (!json.containsKey(key)) {
        throw SyncException('云端 Plan 缺少字段 $key。');
      }
    }
    final parentGoalId = _nullableString(json, 'parent_goal_id');
    if (parentGoalId != null &&
        (!isUuid(parentGoalId) || parentGoalId == recordId)) {
      throw const SyncException('云端 Plan 父目标 ID 无效。');
    }
    final titleValue = json['title'];
    if (titleValue is! String || titleValue.trim().isEmpty) {
      throw const SyncException('云端 Plan 标题无效。');
    }
    final levelValue = json['goal_level'];
    final statusValue = json['status'];
    if (levelValue is! String || statusValue is! String) {
      throw const SyncException('云端 Plan 层级或状态无效。');
    }
    late final PlanGoalLevel goalLevel;
    late final PlanGoalStatus status;
    try {
      goalLevel = planGoalLevelFromDatabase(levelValue);
      status = planGoalStatusFromDatabase(statusValue);
    } on StateError {
      throw const SyncException('云端 Plan 层级或状态无效。');
    }
    final completedAt = _nullableNonNegativeInt(json, 'completed_at');
    final result = PlanSyncPayload(
      parentGoalId: parentGoalId,
      title: titleValue.trim(),
      description: _nullableString(json, 'description'),
      goalLevel: goalLevel,
      status: status,
      startDate: _nullableDate(json, 'start_date'),
      targetDate: _nullableDate(json, 'target_date'),
      completedAt: completedAt,
      archivedAt: _nullableNonNegativeInt(json, 'archived_at'),
      sortOrder: _nonNegativeInt(json, 'sort_order'),
      createdAt: _nonNegativeInt(json, 'created_at'),
    );
    validate(recordId: recordId, payload: result);
    return result;
  }

  void validate({required String recordId, required PlanSyncPayload payload}) {
    final parentId = payload.parentGoalId;
    if (parentId != null && (!isUuid(parentId) || parentId == recordId)) {
      throw const SyncException('云端 Plan 父目标 ID 无效。');
    }
    if (payload.title.trim().isEmpty ||
        payload.sortOrder < 0 ||
        payload.createdAt < 0 ||
        (payload.completedAt != null && payload.completedAt! < 0) ||
        (payload.archivedAt != null && payload.archivedAt! < 0)) {
      throw const SyncException('云端 Plan 业务字段无效。');
    }
    for (final date in [payload.startDate, payload.targetDate]) {
      if (date != null && !_dateTimeService.isValidLocalDateString(date)) {
        throw const SyncException('云端 Plan 日期无效。');
      }
    }
    if (payload.startDate != null &&
        payload.targetDate != null &&
        payload.targetDate!.compareTo(payload.startDate!) < 0) {
      throw const SyncException('云端 Plan 目标日期早于开始日期。');
    }
    if ((payload.status == PlanGoalStatus.completed) !=
        (payload.completedAt != null)) {
      throw const SyncException('云端 Plan 完成状态与时间不一致。');
    }
  }

  static bool isUuid(String value) => _uuidPattern.hasMatch(value);

  String? _nullableString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value != null && value is! String) {
      throw SyncException('云端 Plan 字段 $key 无效。');
    }
    return value as String?;
  }

  String? _nullableDate(Map<String, Object?> payload, String key) {
    final value = _nullableString(payload, key);
    if (value != null && !_dateTimeService.isValidLocalDateString(value)) {
      throw SyncException('云端 Plan 日期字段 $key 无效。');
    }
    return value;
  }

  int _nonNegativeInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! int || value < 0) {
      throw SyncException('云端 Plan 字段 $key 必须是非负整数。');
    }
    return value;
  }

  int? _nullableNonNegativeInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is! int || value < 0) {
      throw SyncException('云端 Plan 字段 $key 必须是非负整数或 null。');
    }
    return value;
  }
}
