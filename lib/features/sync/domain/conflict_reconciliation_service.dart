import 'dart:convert';
import 'dart:collection';

import 'package:crypto/crypto.dart';

import 'sync_merge_policy.dart';
import 'sync_record_baseline.dart';

enum ConflictReconciliationOutcome {
  noChange,
  adoptRemote,
  retryLocal,
  mergeAndRetry,
  manualConflict,
}

final class ReconciliationRecordState {
  const ReconciliationRecordState({
    required this.exists,
    required this.tombstone,
    required this.payload,
    required this.serverVersion,
  });

  final bool exists;
  final bool tombstone;
  final Map<String, Object?>? payload;
  final int? serverVersion;
}

final class ConflictReconciliationDecision {
  const ConflictReconciliationDecision({
    required this.outcome,
    required this.reasonCode,
    this.mergedPayload,
  });

  final ConflictReconciliationOutcome outcome;
  final String reasonCode;
  final Map<String, Object?>? mergedPayload;

  bool get isAutomatic =>
      outcome != ConflictReconciliationOutcome.manualConflict;
}

final class ConflictReconciliationService {
  const ConflictReconciliationService();

  ConflictReconciliationDecision reconcile({
    required SyncMergePolicy policy,
    required SyncRecordBaseline? baseline,
    required ReconciliationRecordState local,
    required ReconciliationRecordState remote,
  }) {
    _validateState(local);
    _validateState(remote);

    if (_sameState(policy, local, remote)) {
      return const ConflictReconciliationDecision(
        outcome: ConflictReconciliationOutcome.noChange,
        reasonCode: 'exact_equality',
      );
    }

    if (!_hasTrustedBaseline(policy, baseline)) {
      return const ConflictReconciliationDecision(
        outcome: ConflictReconciliationOutcome.manualConflict,
        reasonCode: 'no_trusted_baseline',
      );
    }
    final trusted = baseline!;
    if (remote.serverVersion == null ||
        trusted.baseServerVersion > remote.serverVersion! ||
        (local.serverVersion != null &&
            trusted.baseServerVersion > local.serverVersion!)) {
      return const ConflictReconciliationDecision(
        outcome: ConflictReconciliationOutcome.manualConflict,
        reasonCode: 'baseline_version_invalid',
      );
    }

    if (!local.exists || !remote.exists) {
      return const ConflictReconciliationDecision(
        outcome: ConflictReconciliationOutcome.manualConflict,
        reasonCode: 'record_presence_ambiguous',
      );
    }

    if (local.tombstone || remote.tombstone) {
      return _reconcileDeletion(
        policy: policy,
        baseline: trusted,
        local: local,
        remote: remote,
      );
    }

    if (trusted.baseTombstone || !trusted.baseExists) {
      return const ConflictReconciliationDecision(
        outcome: ConflictReconciliationOutcome.manualConflict,
        reasonCode: 'live_record_has_no_live_base',
      );
    }

    final localHashes = hashGroups(policy, local.payload!);
    final remoteHashes = hashGroups(policy, remote.payload!);
    final merged = Map<String, Object?>.from(remote.payload!);
    var choseLocal = false;
    var choseRemote = false;

    for (final group in policy.fieldGroups) {
      final baseHash = trusted.groupHashes[group.id]!;
      final localHash = localHashes[group.id]!;
      final remoteHash = remoteHashes[group.id]!;
      if (localHash == remoteHash) {
        _copyGroup(group, local.payload!, merged);
        continue;
      }
      if (localHash == baseHash) {
        choseRemote = true;
        continue;
      }
      if (remoteHash == baseHash) {
        choseLocal = true;
        _copyGroup(group, local.payload!, merged);
        continue;
      }
      return ConflictReconciliationDecision(
        outcome: ConflictReconciliationOutcome.manualConflict,
        reasonCode: 'same_group_changed:${group.id}',
      );
    }

    for (final key in policy.derivedKeys) {
      if (local.payload!.containsKey(key)) merged[key] = local.payload![key];
    }

    if (choseLocal && choseRemote) {
      return ConflictReconciliationDecision(
        outcome: ConflictReconciliationOutcome.mergeAndRetry,
        reasonCode: 'non_overlapping_groups',
        mergedPayload: Map.unmodifiable(merged),
      );
    }
    if (choseLocal) {
      return const ConflictReconciliationDecision(
        outcome: ConflictReconciliationOutcome.retryLocal,
        reasonCode: 'remote_matches_base',
      );
    }
    if (choseRemote) {
      return const ConflictReconciliationDecision(
        outcome: ConflictReconciliationOutcome.adoptRemote,
        reasonCode: 'local_matches_base',
      );
    }
    return const ConflictReconciliationDecision(
      outcome: ConflictReconciliationOutcome.noChange,
      reasonCode: 'same_resulting_groups',
    );
  }

  Map<String, String> hashGroups(
    SyncMergePolicy policy,
    Map<String, Object?> payload,
  ) {
    final groupedKeys = policy.fieldGroups
        .expand((group) => group.keys)
        .toSet();
    final unsupported = payload.keys.toSet()
      ..removeAll(groupedKeys)
      ..removeAll(policy.derivedKeys);
    if (unsupported.isNotEmpty) {
      throw ArgumentError(
        'Merge policy ${policy.entityType.wireName} does not cover: '
        '${unsupported.toList()..sort()}',
      );
    }
    return Map.unmodifiable({
      for (final group in policy.fieldGroups)
        group.id: _hash({for (final key in group.keys) key: payload[key]}),
    });
  }

  String hashCanonicalValue(Object? value) {
    final canonical = jsonEncode(_canonicalize(value));
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  bool _hasTrustedBaseline(
    SyncMergePolicy policy,
    SyncRecordBaseline? baseline,
  ) {
    if (baseline == null ||
        baseline.entityType != policy.entityType.wireName ||
        baseline.groupHashes.length != policy.fieldGroups.length) {
      return false;
    }
    return policy.fieldGroups.every(
      (group) => baseline.groupHashes.containsKey(group.id),
    );
  }

  ConflictReconciliationDecision _reconcileDeletion({
    required SyncMergePolicy policy,
    required SyncRecordBaseline baseline,
    required ReconciliationRecordState local,
    required ReconciliationRecordState remote,
  }) {
    if (local.tombstone && remote.tombstone) {
      return const ConflictReconciliationDecision(
        outcome: ConflictReconciliationOutcome.noChange,
        reasonCode: 'both_deleted',
      );
    }
    if (!baseline.baseExists || baseline.baseTombstone) {
      return const ConflictReconciliationDecision(
        outcome: ConflictReconciliationOutcome.manualConflict,
        reasonCode: 'delete_without_live_base',
      );
    }
    if (local.tombstone) {
      final remoteUnchanged = _matchesBaseline(policy, baseline, remote);
      return ConflictReconciliationDecision(
        outcome: remoteUnchanged
            ? ConflictReconciliationOutcome.retryLocal
            : ConflictReconciliationOutcome.manualConflict,
        reasonCode: remoteUnchanged
            ? 'local_delete_remote_unchanged'
            : 'delete_vs_remote_update',
      );
    }
    final localUnchanged = _matchesBaseline(policy, baseline, local);
    return ConflictReconciliationDecision(
      outcome: localUnchanged
          ? ConflictReconciliationOutcome.adoptRemote
          : ConflictReconciliationOutcome.manualConflict,
      reasonCode: localUnchanged
          ? 'remote_delete_local_unchanged'
          : 'remote_delete_vs_local_update',
    );
  }

  bool _matchesBaseline(
    SyncMergePolicy policy,
    SyncRecordBaseline baseline,
    ReconciliationRecordState state,
  ) {
    if (!state.exists || state.tombstone || state.payload == null) return false;
    final hashes = hashGroups(policy, state.payload!);
    return policy.fieldGroups.every(
      (group) => hashes[group.id] == baseline.groupHashes[group.id],
    );
  }

  bool _sameState(
    SyncMergePolicy policy,
    ReconciliationRecordState left,
    ReconciliationRecordState right,
  ) {
    if (left.exists != right.exists || left.tombstone != right.tombstone) {
      return false;
    }
    if (!left.exists || left.tombstone) return true;
    if (left.payload == null || right.payload == null) return false;
    final leftHashes = hashGroups(policy, left.payload!);
    final rightHashes = hashGroups(policy, right.payload!);
    return policy.fieldGroups.every(
      (group) => leftHashes[group.id] == rightHashes[group.id],
    );
  }

  void _copyGroup(
    SyncFieldGroup group,
    Map<String, Object?> source,
    Map<String, Object?> target,
  ) {
    for (final key in group.keys) {
      if (source.containsKey(key)) {
        target[key] = source[key];
      } else {
        target.remove(key);
      }
    }
  }

  String _hash(Map<String, Object?> value) {
    return hashCanonicalValue(value);
  }

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw ArgumentError('Sync payload maps require string keys.');
        }
        sorted[entry.key as String] = _canonicalize(entry.value);
      }
      return sorted;
    }
    if (value is List) return value.map(_canonicalize).toList(growable: false);
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    throw ArgumentError('Unsupported sync payload value: ${value.runtimeType}');
  }

  void _validateState(ReconciliationRecordState state) {
    if ((!state.exists && (state.tombstone || state.payload != null)) ||
        (state.tombstone && state.payload != null) ||
        (state.exists && !state.tombstone && state.payload == null) ||
        (state.serverVersion != null && state.serverVersion! < 0)) {
      throw ArgumentError('Invalid reconciliation record state.');
    }
  }
}
