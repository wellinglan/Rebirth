import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_item.dart';
import 'package:rebirth/features/sync/domain/sync_result.dart';

final class SyncPushRequestDto {
  SyncPushRequestDto({required this.deviceId, required List<SyncItem> items})
    : items = List.unmodifiable(items);

  final String deviceId;
  final List<SyncItem> items;

  Map<String, Object?> toJson() {
    return {
      'device_id': deviceId,
      'items': items
          .map(
            (item) => <String, Object?>{
              'table': item.tableName,
              'id': item.recordId,
              'payload': item.payload,
              'updated_at': item.updatedAt,
              'deleted_at': item.deletedAt,
              'origin_device_id': item.originDeviceId,
              'client_version': item.clientVersion,
            },
          )
          .toList(growable: false),
    };
  }
}

final class SyncPushResponseDto {
  SyncPushResponseDto({
    required List<SyncedRecord> accepted,
    required List<SyncConflict> conflicts,
  }) : accepted = List.unmodifiable(accepted),
       conflicts = List.unmodifiable(conflicts);

  factory SyncPushResponseDto.fromJson(Map<String, Object?> json) {
    return SyncPushResponseDto(
      accepted: _mapList(json['accepted'], (item) {
        return SyncedRecord(
          tableName: item['table'] as String,
          recordId: item['id'] as String,
          serverVersion: item['server_version'] as int,
        );
      }),
      conflicts: _mapList(json['conflicts'], (item) {
        return SyncConflict(
          tableName: item['table'] as String,
          recordId: item['id'] as String,
          serverVersion: item['server_version'] as int,
          reason: item['reason'] as String,
        );
      }),
    );
  }

  final List<SyncedRecord> accepted;
  final List<SyncConflict> conflicts;
}

final class SyncPullRequestDto {
  SyncPullRequestDto({
    required this.deviceId,
    required this.sinceServerVersion,
    required List<String> tables,
  }) : tables = List.unmodifiable(tables);

  final String deviceId;
  final int sinceServerVersion;
  final List<String> tables;

  Map<String, Object?> toJson() {
    return {
      'device_id': deviceId,
      'since_server_version': sinceServerVersion,
      'tables': tables,
    };
  }
}

final class PulledSyncItemDto {
  PulledSyncItemDto({
    required this.tableName,
    required this.recordId,
    required Map<String, Object?> payload,
    required this.updatedAt,
    required this.deletedAt,
    required this.originDeviceId,
    required this.serverVersion,
  }) : payload = Map.unmodifiable(payload);

  factory PulledSyncItemDto.fromJson(Map<String, Object?> json) {
    final rawPayload = json['payload'];
    if (rawPayload is! Map) {
      throw const FormatException('Invalid sync payload.');
    }
    return PulledSyncItemDto(
      tableName: json['table'] as String,
      recordId: json['id'] as String,
      payload: Map<String, Object?>.from(rawPayload),
      updatedAt: json['updated_at'] as int,
      deletedAt: json['deleted_at'] as int?,
      originDeviceId: json['origin_device_id'] as String,
      serverVersion: json['server_version'] as int,
    );
  }

  final String tableName;
  final String recordId;
  final Map<String, Object?> payload;
  final int updatedAt;
  final int? deletedAt;
  final String originDeviceId;
  final int serverVersion;
}

final class SyncPullResponseDto {
  SyncPullResponseDto({
    required this.serverVersion,
    required List<PulledSyncItemDto> items,
  }) : items = List.unmodifiable(items);

  factory SyncPullResponseDto.fromJson(Map<String, Object?> json) {
    return SyncPullResponseDto(
      serverVersion: json['server_version'] as int,
      items: _mapList(json['items'], PulledSyncItemDto.fromJson),
    );
  }

  final int serverVersion;
  final List<PulledSyncItemDto> items;
}

List<T> _mapList<T>(
  Object? value,
  T Function(Map<String, Object?> item) mapper,
) {
  if (value is! List) throw const FormatException('Invalid sync list.');
  return value.map((item) {
    if (item is! Map) throw const FormatException('Invalid sync item.');
    return mapper(Map<String, Object?>.from(item));
  }).toList(growable: false);
}
