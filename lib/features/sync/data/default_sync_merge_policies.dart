import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_merge_policy.dart';

final class SyncMergePolicyRegistry {
  SyncMergePolicyRegistry(Iterable<SyncMergePolicy> policies)
    : _policies = {for (final policy in policies) policy.entityType: policy} {
    if (_policies.length != policies.length) {
      throw ArgumentError('Duplicate sync merge policy.');
    }
  }

  final Map<SyncEntityType, SyncMergePolicy> _policies;

  SyncMergePolicy policyFor(SyncEntityType entityType) {
    final policy = _policies[entityType];
    if (policy == null) {
      throw StateError('No merge policy for ${entityType.wireName}.');
    }
    return policy;
  }
}

SyncMergePolicyRegistry createDefaultSyncMergePolicyRegistry() {
  SyncFieldGroup group(String id, List<String> keys) =>
      SyncFieldGroup(id: id, keys: keys);

  return SyncMergePolicyRegistry([
    MapSyncMergePolicy(
      entityType: SyncEntityType.profile,
      fieldGroups: [
        group('display_name', ['display_name']),
        group('growth_focus', ['growth_focus']),
        group('timezone', ['timezone_id']),
      ],
      derivedKeys: const ['updated_at'],
    ),
    MapSyncMergePolicy(
      entityType: SyncEntityType.plan,
      fieldGroups: [
        group('title', ['title']),
        group('description', ['description']),
        group('hierarchy', ['parent_goal_id', 'goal_level', 'sort_order']),
        group('date_rule', ['start_date', 'target_date']),
        group('lifecycle', ['status', 'completed_at', 'archived_at']),
        group('identity', ['created_at']),
      ],
    ),
    MapSyncMergePolicy(
      entityType: SyncEntityType.today,
      fieldGroups: [
        group('identity', [
          'record_date',
          'timezone_offset_minutes',
          'created_at',
        ]),
        group('priority_1', [
          'priority_1',
          'priority_1_completed',
          'priority_1_goal_id',
        ]),
        group('priority_2', [
          'priority_2',
          'priority_2_completed',
          'priority_2_goal_id',
        ]),
        group('priority_3', [
          'priority_3',
          'priority_3_completed',
          'priority_3_goal_id',
        ]),
        group('wellbeing_scale', ['wellbeing_score_scale']),
        group('mood_score', ['mood_score']),
        group('mood_description', ['mood_description']),
        group('energy_score', ['energy_score']),
        group('energy_description', ['energy_description']),
        group('research', ['research_minutes', 'research_description']),
        group('learning', ['learning_minutes', 'learning_description']),
        group('daily_note', ['daily_note']),
        group('lifecycle', ['record_status']),
      ],
    ),
    MapSyncMergePolicy(
      entityType: SyncEntityType.health,
      fieldGroups: [
        group('identity', [
          'record_date',
          'timezone_offset_minutes',
          'data_source',
          'source_record_id',
          'created_at',
        ]),
        group('sleep', ['sleep_duration_minutes', 'sleep_description']),
        group('weight', ['weight_kg', 'weight_description']),
        group('water', ['water_intake_ml', 'water_description']),
        group('exercise', [
          'exercise_type',
          'exercise_duration_minutes',
          'exercise_description',
        ]),
        group('physical_state', [
          'physical_state_score',
          'physical_state_score_scale',
          'physical_state_description',
        ]),
        group('note', ['note']),
      ],
    ),
    MapSyncMergePolicy(
      entityType: SyncEntityType.journal,
      fieldGroups: [
        group('identity', [
          'entry_date',
          'timezone_offset_minutes',
          'created_at',
        ]),
        group('lifecycle', ['entry_status']),
        group('content', [
          'journal_payload_schema_version',
          'prompt_items',
          'most_important_accomplishment',
          'most_draining_event',
          'emotion_source',
          'learning',
          'tomorrow_adjustment',
        ]),
      ],
    ),
    MapSyncMergePolicy(
      entityType: SyncEntityType.journalPromptConfiguration,
      fieldGroups: [
        group('prompt_configuration', [
          'configuration_version',
          'created_at',
          'logical_key',
          'payload_schema_version',
          'prompts',
        ]),
      ],
    ),
    MapSyncMergePolicy(
      entityType: SyncEntityType.aiReport,
      fieldGroups: [
        group('report_aggregate', [
          'created_at',
          'current_version',
          'generation_source',
          'period_end_date',
          'period_start_date',
          'quality',
          'report_status',
          'report_type',
          'sensitivity',
          'title',
          'versions',
        ]),
      ],
    ),
  ]);
}
