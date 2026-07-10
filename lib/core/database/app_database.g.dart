// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: databaseUuid.v4,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncedAt = GeneratedColumn<int>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originDeviceIdMeta = const VerificationMeta(
    'originDeviceId',
  );
  @override
  late final GeneratedColumn<String> originDeviceId = GeneratedColumn<String>(
    'origin_device_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _growthFocusMeta = const VerificationMeta(
    'growthFocus',
  );
  @override
  late final GeneratedColumn<String> growthFocus = GeneratedColumn<String>(
    'growth_focus',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timezoneIdMeta = const VerificationMeta(
    'timezoneId',
  );
  @override
  late final GeneratedColumn<String> timezoneId = GeneratedColumn<String>(
    'timezone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    deletedAt,
    displayName,
    growthFocus,
    timezoneId,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('origin_device_id')) {
      context.handle(
        _originDeviceIdMeta,
        originDeviceId.isAcceptableOrUnknown(
          data['origin_device_id']!,
          _originDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('growth_focus')) {
      context.handle(
        _growthFocusMeta,
        growthFocus.isAcceptableOrUnknown(
          data['growth_focus']!,
          _growthFocusMeta,
        ),
      );
    }
    if (data.containsKey('timezone_id')) {
      context.handle(
        _timezoneIdMeta,
        timezoneId.isAcceptableOrUnknown(data['timezone_id']!, _timezoneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_timezoneIdMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_at'],
      ),
      originDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      growthFocus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}growth_focus'],
      ),
      timezoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone_id'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;
  final int? serverVersion;
  final int? lastSyncedAt;
  final String? originDeviceId;
  final int? deletedAt;
  final String? displayName;
  final String? growthFocus;
  final String timezoneId;
  final bool isActive;
  const UserProfile({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.serverVersion,
    this.lastSyncedAt,
    this.originDeviceId,
    this.deletedAt,
    this.displayName,
    this.growthFocus,
    required this.timezoneId,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || serverVersion != null) {
      map['server_version'] = Variable<int>(serverVersion);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt);
    }
    if (!nullToAbsent || originDeviceId != null) {
      map['origin_device_id'] = Variable<String>(originDeviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || growthFocus != null) {
      map['growth_focus'] = Variable<String>(growthFocus);
    }
    map['timezone_id'] = Variable<String>(timezoneId);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
      serverVersion: serverVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(serverVersion),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      originDeviceId: originDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(originDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      growthFocus: growthFocus == null && nullToAbsent
          ? const Value.absent()
          : Value(growthFocus),
      timezoneId: Value(timezoneId),
      isActive: Value(isActive),
    );
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      serverVersion: serializer.fromJson<int?>(json['serverVersion']),
      lastSyncedAt: serializer.fromJson<int?>(json['lastSyncedAt']),
      originDeviceId: serializer.fromJson<String?>(json['originDeviceId']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      growthFocus: serializer.fromJson<String?>(json['growthFocus']),
      timezoneId: serializer.fromJson<String>(json['timezoneId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'serverVersion': serializer.toJson<int?>(serverVersion),
      'lastSyncedAt': serializer.toJson<int?>(lastSyncedAt),
      'originDeviceId': serializer.toJson<String?>(originDeviceId),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'displayName': serializer.toJson<String?>(displayName),
      'growthFocus': serializer.toJson<String?>(growthFocus),
      'timezoneId': serializer.toJson<String>(timezoneId),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  UserProfile copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
    Value<int?> serverVersion = const Value.absent(),
    Value<int?> lastSyncedAt = const Value.absent(),
    Value<String?> originDeviceId = const Value.absent(),
    Value<int?> deletedAt = const Value.absent(),
    Value<String?> displayName = const Value.absent(),
    Value<String?> growthFocus = const Value.absent(),
    String? timezoneId,
    bool? isActive,
  }) => UserProfile(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    serverVersion: serverVersion.present
        ? serverVersion.value
        : this.serverVersion,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    originDeviceId: originDeviceId.present
        ? originDeviceId.value
        : this.originDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    displayName: displayName.present ? displayName.value : this.displayName,
    growthFocus: growthFocus.present ? growthFocus.value : this.growthFocus,
    timezoneId: timezoneId ?? this.timezoneId,
    isActive: isActive ?? this.isActive,
  );
  UserProfile copyWithCompanion(UserProfilesCompanion data) {
    return UserProfile(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      originDeviceId: data.originDeviceId.present
          ? data.originDeviceId.value
          : this.originDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      growthFocus: data.growthFocus.present
          ? data.growthFocus.value
          : this.growthFocus,
      timezoneId: data.timezoneId.present
          ? data.timezoneId.value
          : this.timezoneId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('displayName: $displayName, ')
          ..write('growthFocus: $growthFocus, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    deletedAt,
    displayName,
    growthFocus,
    timezoneId,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus &&
          other.serverVersion == this.serverVersion &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.originDeviceId == this.originDeviceId &&
          other.deletedAt == this.deletedAt &&
          other.displayName == this.displayName &&
          other.growthFocus == this.growthFocus &&
          other.timezoneId == this.timezoneId &&
          other.isActive == this.isActive);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfile> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> syncStatus;
  final Value<int?> serverVersion;
  final Value<int?> lastSyncedAt;
  final Value<String?> originDeviceId;
  final Value<int?> deletedAt;
  final Value<String?> displayName;
  final Value<String?> growthFocus;
  final Value<String> timezoneId;
  final Value<bool> isActive;
  final Value<int> rowid;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.displayName = const Value.absent(),
    this.growthFocus = const Value.absent(),
    this.timezoneId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.displayName = const Value.absent(),
    this.growthFocus = const Value.absent(),
    required String timezoneId,
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : timezoneId = Value(timezoneId);
  static Insertable<UserProfile> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? syncStatus,
    Expression<int>? serverVersion,
    Expression<int>? lastSyncedAt,
    Expression<String>? originDeviceId,
    Expression<int>? deletedAt,
    Expression<String>? displayName,
    Expression<String>? growthFocus,
    Expression<String>? timezoneId,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverVersion != null) 'server_version': serverVersion,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (originDeviceId != null) 'origin_device_id': originDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (displayName != null) 'display_name': displayName,
      if (growthFocus != null) 'growth_focus': growthFocus,
      if (timezoneId != null) 'timezone_id': timezoneId,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfilesCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? syncStatus,
    Value<int?>? serverVersion,
    Value<int?>? lastSyncedAt,
    Value<String?>? originDeviceId,
    Value<int?>? deletedAt,
    Value<String?>? displayName,
    Value<String?>? growthFocus,
    Value<String>? timezoneId,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      serverVersion: serverVersion ?? this.serverVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      originDeviceId: originDeviceId ?? this.originDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      displayName: displayName ?? this.displayName,
      growthFocus: growthFocus ?? this.growthFocus,
      timezoneId: timezoneId ?? this.timezoneId,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt.value);
    }
    if (originDeviceId.present) {
      map['origin_device_id'] = Variable<String>(originDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (growthFocus.present) {
      map['growth_focus'] = Variable<String>(growthFocus.value);
    }
    if (timezoneId.present) {
      map['timezone_id'] = Variable<String>(timezoneId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('displayName: $displayName, ')
          ..write('growthFocus: $growthFocus, ')
          ..write('timezoneId: $timezoneId, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: databaseUuid.v4,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncedAt = GeneratedColumn<int>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originDeviceIdMeta = const VerificationMeta(
    'originDeviceId',
  );
  @override
  late final GeneratedColumn<String> originDeviceId = GeneratedColumn<String>(
    'origin_device_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES user_profiles (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _localInstallationIdMeta =
      const VerificationMeta('localInstallationId');
  @override
  late final GeneratedColumn<String> localInstallationId =
      GeneratedColumn<String>(
        'local_installation_id',
        aliasedName,
        false,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 36,
          maxTextLength: 36,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _localeMeta = const VerificationMeta('locale');
  @override
  late final GeneratedColumn<String> locale = GeneratedColumn<String>(
    'locale',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('zh_CN'),
  );
  static const VerificationMeta _firstDayOfWeekMeta = const VerificationMeta(
    'firstDayOfWeek',
  );
  @override
  late final GeneratedColumn<int> firstDayOfWeek = GeneratedColumn<int>(
    'first_day_of_week',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _onboardingCompletedMeta =
      const VerificationMeta('onboardingCompleted');
  @override
  late final GeneratedColumn<bool> onboardingCompleted = GeneratedColumn<bool>(
    'onboarding_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarding_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _aiDataSharingEnabledMeta =
      const VerificationMeta('aiDataSharingEnabled');
  @override
  late final GeneratedColumn<bool> aiDataSharingEnabled = GeneratedColumn<bool>(
    'ai_data_sharing_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ai_data_sharing_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _aiDataSharingConsentAtMeta =
      const VerificationMeta('aiDataSharingConsentAt');
  @override
  late final GeneratedColumn<int> aiDataSharingConsentAt = GeneratedColumn<int>(
    'ai_data_sharing_consent_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudSyncEnabledMeta = const VerificationMeta(
    'cloudSyncEnabled',
  );
  @override
  late final GeneratedColumn<bool> cloudSyncEnabled = GeneratedColumn<bool>(
    'cloud_sync_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cloud_sync_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    userId,
    localInstallationId,
    themeMode,
    locale,
    firstDayOfWeek,
    onboardingCompleted,
    aiDataSharingEnabled,
    aiDataSharingConsentAt,
    cloudSyncEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('origin_device_id')) {
      context.handle(
        _originDeviceIdMeta,
        originDeviceId.isAcceptableOrUnknown(
          data['origin_device_id']!,
          _originDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('local_installation_id')) {
      context.handle(
        _localInstallationIdMeta,
        localInstallationId.isAcceptableOrUnknown(
          data['local_installation_id']!,
          _localInstallationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localInstallationIdMeta);
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('locale')) {
      context.handle(
        _localeMeta,
        locale.isAcceptableOrUnknown(data['locale']!, _localeMeta),
      );
    }
    if (data.containsKey('first_day_of_week')) {
      context.handle(
        _firstDayOfWeekMeta,
        firstDayOfWeek.isAcceptableOrUnknown(
          data['first_day_of_week']!,
          _firstDayOfWeekMeta,
        ),
      );
    }
    if (data.containsKey('onboarding_completed')) {
      context.handle(
        _onboardingCompletedMeta,
        onboardingCompleted.isAcceptableOrUnknown(
          data['onboarding_completed']!,
          _onboardingCompletedMeta,
        ),
      );
    }
    if (data.containsKey('ai_data_sharing_enabled')) {
      context.handle(
        _aiDataSharingEnabledMeta,
        aiDataSharingEnabled.isAcceptableOrUnknown(
          data['ai_data_sharing_enabled']!,
          _aiDataSharingEnabledMeta,
        ),
      );
    }
    if (data.containsKey('ai_data_sharing_consent_at')) {
      context.handle(
        _aiDataSharingConsentAtMeta,
        aiDataSharingConsentAt.isAcceptableOrUnknown(
          data['ai_data_sharing_consent_at']!,
          _aiDataSharingConsentAtMeta,
        ),
      );
    }
    if (data.containsKey('cloud_sync_enabled')) {
      context.handle(
        _cloudSyncEnabledMeta,
        cloudSyncEnabled.isAcceptableOrUnknown(
          data['cloud_sync_enabled']!,
          _cloudSyncEnabledMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_at'],
      ),
      originDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_device_id'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      localInstallationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_installation_id'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      locale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locale'],
      )!,
      firstDayOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_day_of_week'],
      )!,
      onboardingCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarding_completed'],
      )!,
      aiDataSharingEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ai_data_sharing_enabled'],
      )!,
      aiDataSharingConsentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ai_data_sharing_consent_at'],
      ),
      cloudSyncEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cloud_sync_enabled'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;
  final int? serverVersion;
  final int? lastSyncedAt;
  final String? originDeviceId;
  final String userId;
  final String localInstallationId;
  final String themeMode;
  final String locale;
  final int firstDayOfWeek;
  final bool onboardingCompleted;
  final bool aiDataSharingEnabled;
  final int? aiDataSharingConsentAt;
  final bool cloudSyncEnabled;
  const AppSetting({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.serverVersion,
    this.lastSyncedAt,
    this.originDeviceId,
    required this.userId,
    required this.localInstallationId,
    required this.themeMode,
    required this.locale,
    required this.firstDayOfWeek,
    required this.onboardingCompleted,
    required this.aiDataSharingEnabled,
    this.aiDataSharingConsentAt,
    required this.cloudSyncEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || serverVersion != null) {
      map['server_version'] = Variable<int>(serverVersion);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt);
    }
    if (!nullToAbsent || originDeviceId != null) {
      map['origin_device_id'] = Variable<String>(originDeviceId);
    }
    map['user_id'] = Variable<String>(userId);
    map['local_installation_id'] = Variable<String>(localInstallationId);
    map['theme_mode'] = Variable<String>(themeMode);
    map['locale'] = Variable<String>(locale);
    map['first_day_of_week'] = Variable<int>(firstDayOfWeek);
    map['onboarding_completed'] = Variable<bool>(onboardingCompleted);
    map['ai_data_sharing_enabled'] = Variable<bool>(aiDataSharingEnabled);
    if (!nullToAbsent || aiDataSharingConsentAt != null) {
      map['ai_data_sharing_consent_at'] = Variable<int>(aiDataSharingConsentAt);
    }
    map['cloud_sync_enabled'] = Variable<bool>(cloudSyncEnabled);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
      serverVersion: serverVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(serverVersion),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      originDeviceId: originDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(originDeviceId),
      userId: Value(userId),
      localInstallationId: Value(localInstallationId),
      themeMode: Value(themeMode),
      locale: Value(locale),
      firstDayOfWeek: Value(firstDayOfWeek),
      onboardingCompleted: Value(onboardingCompleted),
      aiDataSharingEnabled: Value(aiDataSharingEnabled),
      aiDataSharingConsentAt: aiDataSharingConsentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(aiDataSharingConsentAt),
      cloudSyncEnabled: Value(cloudSyncEnabled),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      serverVersion: serializer.fromJson<int?>(json['serverVersion']),
      lastSyncedAt: serializer.fromJson<int?>(json['lastSyncedAt']),
      originDeviceId: serializer.fromJson<String?>(json['originDeviceId']),
      userId: serializer.fromJson<String>(json['userId']),
      localInstallationId: serializer.fromJson<String>(
        json['localInstallationId'],
      ),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      locale: serializer.fromJson<String>(json['locale']),
      firstDayOfWeek: serializer.fromJson<int>(json['firstDayOfWeek']),
      onboardingCompleted: serializer.fromJson<bool>(
        json['onboardingCompleted'],
      ),
      aiDataSharingEnabled: serializer.fromJson<bool>(
        json['aiDataSharingEnabled'],
      ),
      aiDataSharingConsentAt: serializer.fromJson<int?>(
        json['aiDataSharingConsentAt'],
      ),
      cloudSyncEnabled: serializer.fromJson<bool>(json['cloudSyncEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'serverVersion': serializer.toJson<int?>(serverVersion),
      'lastSyncedAt': serializer.toJson<int?>(lastSyncedAt),
      'originDeviceId': serializer.toJson<String?>(originDeviceId),
      'userId': serializer.toJson<String>(userId),
      'localInstallationId': serializer.toJson<String>(localInstallationId),
      'themeMode': serializer.toJson<String>(themeMode),
      'locale': serializer.toJson<String>(locale),
      'firstDayOfWeek': serializer.toJson<int>(firstDayOfWeek),
      'onboardingCompleted': serializer.toJson<bool>(onboardingCompleted),
      'aiDataSharingEnabled': serializer.toJson<bool>(aiDataSharingEnabled),
      'aiDataSharingConsentAt': serializer.toJson<int?>(aiDataSharingConsentAt),
      'cloudSyncEnabled': serializer.toJson<bool>(cloudSyncEnabled),
    };
  }

  AppSetting copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
    Value<int?> serverVersion = const Value.absent(),
    Value<int?> lastSyncedAt = const Value.absent(),
    Value<String?> originDeviceId = const Value.absent(),
    String? userId,
    String? localInstallationId,
    String? themeMode,
    String? locale,
    int? firstDayOfWeek,
    bool? onboardingCompleted,
    bool? aiDataSharingEnabled,
    Value<int?> aiDataSharingConsentAt = const Value.absent(),
    bool? cloudSyncEnabled,
  }) => AppSetting(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    serverVersion: serverVersion.present
        ? serverVersion.value
        : this.serverVersion,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    originDeviceId: originDeviceId.present
        ? originDeviceId.value
        : this.originDeviceId,
    userId: userId ?? this.userId,
    localInstallationId: localInstallationId ?? this.localInstallationId,
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    aiDataSharingEnabled: aiDataSharingEnabled ?? this.aiDataSharingEnabled,
    aiDataSharingConsentAt: aiDataSharingConsentAt.present
        ? aiDataSharingConsentAt.value
        : this.aiDataSharingConsentAt,
    cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      originDeviceId: data.originDeviceId.present
          ? data.originDeviceId.value
          : this.originDeviceId,
      userId: data.userId.present ? data.userId.value : this.userId,
      localInstallationId: data.localInstallationId.present
          ? data.localInstallationId.value
          : this.localInstallationId,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      locale: data.locale.present ? data.locale.value : this.locale,
      firstDayOfWeek: data.firstDayOfWeek.present
          ? data.firstDayOfWeek.value
          : this.firstDayOfWeek,
      onboardingCompleted: data.onboardingCompleted.present
          ? data.onboardingCompleted.value
          : this.onboardingCompleted,
      aiDataSharingEnabled: data.aiDataSharingEnabled.present
          ? data.aiDataSharingEnabled.value
          : this.aiDataSharingEnabled,
      aiDataSharingConsentAt: data.aiDataSharingConsentAt.present
          ? data.aiDataSharingConsentAt.value
          : this.aiDataSharingConsentAt,
      cloudSyncEnabled: data.cloudSyncEnabled.present
          ? data.cloudSyncEnabled.value
          : this.cloudSyncEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('userId: $userId, ')
          ..write('localInstallationId: $localInstallationId, ')
          ..write('themeMode: $themeMode, ')
          ..write('locale: $locale, ')
          ..write('firstDayOfWeek: $firstDayOfWeek, ')
          ..write('onboardingCompleted: $onboardingCompleted, ')
          ..write('aiDataSharingEnabled: $aiDataSharingEnabled, ')
          ..write('aiDataSharingConsentAt: $aiDataSharingConsentAt, ')
          ..write('cloudSyncEnabled: $cloudSyncEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    userId,
    localInstallationId,
    themeMode,
    locale,
    firstDayOfWeek,
    onboardingCompleted,
    aiDataSharingEnabled,
    aiDataSharingConsentAt,
    cloudSyncEnabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus &&
          other.serverVersion == this.serverVersion &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.originDeviceId == this.originDeviceId &&
          other.userId == this.userId &&
          other.localInstallationId == this.localInstallationId &&
          other.themeMode == this.themeMode &&
          other.locale == this.locale &&
          other.firstDayOfWeek == this.firstDayOfWeek &&
          other.onboardingCompleted == this.onboardingCompleted &&
          other.aiDataSharingEnabled == this.aiDataSharingEnabled &&
          other.aiDataSharingConsentAt == this.aiDataSharingConsentAt &&
          other.cloudSyncEnabled == this.cloudSyncEnabled);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> syncStatus;
  final Value<int?> serverVersion;
  final Value<int?> lastSyncedAt;
  final Value<String?> originDeviceId;
  final Value<String> userId;
  final Value<String> localInstallationId;
  final Value<String> themeMode;
  final Value<String> locale;
  final Value<int> firstDayOfWeek;
  final Value<bool> onboardingCompleted;
  final Value<bool> aiDataSharingEnabled;
  final Value<int?> aiDataSharingConsentAt;
  final Value<bool> cloudSyncEnabled;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.userId = const Value.absent(),
    this.localInstallationId = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.locale = const Value.absent(),
    this.firstDayOfWeek = const Value.absent(),
    this.onboardingCompleted = const Value.absent(),
    this.aiDataSharingEnabled = const Value.absent(),
    this.aiDataSharingConsentAt = const Value.absent(),
    this.cloudSyncEnabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    required String userId,
    required String localInstallationId,
    this.themeMode = const Value.absent(),
    this.locale = const Value.absent(),
    this.firstDayOfWeek = const Value.absent(),
    this.onboardingCompleted = const Value.absent(),
    this.aiDataSharingEnabled = const Value.absent(),
    this.aiDataSharingConsentAt = const Value.absent(),
    this.cloudSyncEnabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       localInstallationId = Value(localInstallationId);
  static Insertable<AppSetting> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? syncStatus,
    Expression<int>? serverVersion,
    Expression<int>? lastSyncedAt,
    Expression<String>? originDeviceId,
    Expression<String>? userId,
    Expression<String>? localInstallationId,
    Expression<String>? themeMode,
    Expression<String>? locale,
    Expression<int>? firstDayOfWeek,
    Expression<bool>? onboardingCompleted,
    Expression<bool>? aiDataSharingEnabled,
    Expression<int>? aiDataSharingConsentAt,
    Expression<bool>? cloudSyncEnabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverVersion != null) 'server_version': serverVersion,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (originDeviceId != null) 'origin_device_id': originDeviceId,
      if (userId != null) 'user_id': userId,
      if (localInstallationId != null)
        'local_installation_id': localInstallationId,
      if (themeMode != null) 'theme_mode': themeMode,
      if (locale != null) 'locale': locale,
      if (firstDayOfWeek != null) 'first_day_of_week': firstDayOfWeek,
      if (onboardingCompleted != null)
        'onboarding_completed': onboardingCompleted,
      if (aiDataSharingEnabled != null)
        'ai_data_sharing_enabled': aiDataSharingEnabled,
      if (aiDataSharingConsentAt != null)
        'ai_data_sharing_consent_at': aiDataSharingConsentAt,
      if (cloudSyncEnabled != null) 'cloud_sync_enabled': cloudSyncEnabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? syncStatus,
    Value<int?>? serverVersion,
    Value<int?>? lastSyncedAt,
    Value<String?>? originDeviceId,
    Value<String>? userId,
    Value<String>? localInstallationId,
    Value<String>? themeMode,
    Value<String>? locale,
    Value<int>? firstDayOfWeek,
    Value<bool>? onboardingCompleted,
    Value<bool>? aiDataSharingEnabled,
    Value<int?>? aiDataSharingConsentAt,
    Value<bool>? cloudSyncEnabled,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      serverVersion: serverVersion ?? this.serverVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      originDeviceId: originDeviceId ?? this.originDeviceId,
      userId: userId ?? this.userId,
      localInstallationId: localInstallationId ?? this.localInstallationId,
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      aiDataSharingEnabled: aiDataSharingEnabled ?? this.aiDataSharingEnabled,
      aiDataSharingConsentAt:
          aiDataSharingConsentAt ?? this.aiDataSharingConsentAt,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt.value);
    }
    if (originDeviceId.present) {
      map['origin_device_id'] = Variable<String>(originDeviceId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (localInstallationId.present) {
      map['local_installation_id'] = Variable<String>(
        localInstallationId.value,
      );
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (locale.present) {
      map['locale'] = Variable<String>(locale.value);
    }
    if (firstDayOfWeek.present) {
      map['first_day_of_week'] = Variable<int>(firstDayOfWeek.value);
    }
    if (onboardingCompleted.present) {
      map['onboarding_completed'] = Variable<bool>(onboardingCompleted.value);
    }
    if (aiDataSharingEnabled.present) {
      map['ai_data_sharing_enabled'] = Variable<bool>(
        aiDataSharingEnabled.value,
      );
    }
    if (aiDataSharingConsentAt.present) {
      map['ai_data_sharing_consent_at'] = Variable<int>(
        aiDataSharingConsentAt.value,
      );
    }
    if (cloudSyncEnabled.present) {
      map['cloud_sync_enabled'] = Variable<bool>(cloudSyncEnabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('userId: $userId, ')
          ..write('localInstallationId: $localInstallationId, ')
          ..write('themeMode: $themeMode, ')
          ..write('locale: $locale, ')
          ..write('firstDayOfWeek: $firstDayOfWeek, ')
          ..write('onboardingCompleted: $onboardingCompleted, ')
          ..write('aiDataSharingEnabled: $aiDataSharingEnabled, ')
          ..write('aiDataSharingConsentAt: $aiDataSharingConsentAt, ')
          ..write('cloudSyncEnabled: $cloudSyncEnabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalsTable extends Goals with TableInfo<$GoalsTable, Goal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: databaseUuid.v4,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncedAt = GeneratedColumn<int>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originDeviceIdMeta = const VerificationMeta(
    'originDeviceId',
  );
  @override
  late final GeneratedColumn<String> originDeviceId = GeneratedColumn<String>(
    'origin_device_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_profiles (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _parentGoalIdMeta = const VerificationMeta(
    'parentGoalId',
  );
  @override
  late final GeneratedColumn<String> parentGoalId = GeneratedColumn<String>(
    'parent_goal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalLevelMeta = const VerificationMeta(
    'goalLevel',
  );
  @override
  late final GeneratedColumn<String> goalLevel = GeneratedColumn<String>(
    'goal_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('not_started'),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetDateMeta = const VerificationMeta(
    'targetDate',
  );
  @override
  late final GeneratedColumn<String> targetDate = GeneratedColumn<String>(
    'target_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    deletedAt,
    userId,
    parentGoalId,
    title,
    description,
    goalLevel,
    status,
    startDate,
    targetDate,
    completedAt,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Goal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('origin_device_id')) {
      context.handle(
        _originDeviceIdMeta,
        originDeviceId.isAcceptableOrUnknown(
          data['origin_device_id']!,
          _originDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('parent_goal_id')) {
      context.handle(
        _parentGoalIdMeta,
        parentGoalId.isAcceptableOrUnknown(
          data['parent_goal_id']!,
          _parentGoalIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('goal_level')) {
      context.handle(
        _goalLevelMeta,
        goalLevel.isAcceptableOrUnknown(data['goal_level']!, _goalLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_goalLevelMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('target_date')) {
      context.handle(
        _targetDateMeta,
        targetDate.isAcceptableOrUnknown(data['target_date']!, _targetDateMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Goal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Goal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_at'],
      ),
      originDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      parentGoalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_goal_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      goalLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_level'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      ),
      targetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_date'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $GoalsTable createAlias(String alias) {
    return $GoalsTable(attachedDatabase, alias);
  }
}

class Goal extends DataClass implements Insertable<Goal> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;
  final int? serverVersion;
  final int? lastSyncedAt;
  final String? originDeviceId;
  final int? deletedAt;
  final String userId;
  final String? parentGoalId;
  final String title;
  final String? description;
  final String goalLevel;
  final String status;
  final String? startDate;
  final String? targetDate;
  final int? completedAt;
  final int sortOrder;
  const Goal({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.serverVersion,
    this.lastSyncedAt,
    this.originDeviceId,
    this.deletedAt,
    required this.userId,
    this.parentGoalId,
    required this.title,
    this.description,
    required this.goalLevel,
    required this.status,
    this.startDate,
    this.targetDate,
    this.completedAt,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || serverVersion != null) {
      map['server_version'] = Variable<int>(serverVersion);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt);
    }
    if (!nullToAbsent || originDeviceId != null) {
      map['origin_device_id'] = Variable<String>(originDeviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || parentGoalId != null) {
      map['parent_goal_id'] = Variable<String>(parentGoalId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['goal_level'] = Variable<String>(goalLevel);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<String>(startDate);
    }
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<String>(targetDate);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  GoalsCompanion toCompanion(bool nullToAbsent) {
    return GoalsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
      serverVersion: serverVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(serverVersion),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      originDeviceId: originDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(originDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      userId: Value(userId),
      parentGoalId: parentGoalId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentGoalId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      goalLevel: Value(goalLevel),
      status: Value(status),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      sortOrder: Value(sortOrder),
    );
  }

  factory Goal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Goal(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      serverVersion: serializer.fromJson<int?>(json['serverVersion']),
      lastSyncedAt: serializer.fromJson<int?>(json['lastSyncedAt']),
      originDeviceId: serializer.fromJson<String?>(json['originDeviceId']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      userId: serializer.fromJson<String>(json['userId']),
      parentGoalId: serializer.fromJson<String?>(json['parentGoalId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      goalLevel: serializer.fromJson<String>(json['goalLevel']),
      status: serializer.fromJson<String>(json['status']),
      startDate: serializer.fromJson<String?>(json['startDate']),
      targetDate: serializer.fromJson<String?>(json['targetDate']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'serverVersion': serializer.toJson<int?>(serverVersion),
      'lastSyncedAt': serializer.toJson<int?>(lastSyncedAt),
      'originDeviceId': serializer.toJson<String?>(originDeviceId),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'userId': serializer.toJson<String>(userId),
      'parentGoalId': serializer.toJson<String?>(parentGoalId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'goalLevel': serializer.toJson<String>(goalLevel),
      'status': serializer.toJson<String>(status),
      'startDate': serializer.toJson<String?>(startDate),
      'targetDate': serializer.toJson<String?>(targetDate),
      'completedAt': serializer.toJson<int?>(completedAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Goal copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
    Value<int?> serverVersion = const Value.absent(),
    Value<int?> lastSyncedAt = const Value.absent(),
    Value<String?> originDeviceId = const Value.absent(),
    Value<int?> deletedAt = const Value.absent(),
    String? userId,
    Value<String?> parentGoalId = const Value.absent(),
    String? title,
    Value<String?> description = const Value.absent(),
    String? goalLevel,
    String? status,
    Value<String?> startDate = const Value.absent(),
    Value<String?> targetDate = const Value.absent(),
    Value<int?> completedAt = const Value.absent(),
    int? sortOrder,
  }) => Goal(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    serverVersion: serverVersion.present
        ? serverVersion.value
        : this.serverVersion,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    originDeviceId: originDeviceId.present
        ? originDeviceId.value
        : this.originDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    userId: userId ?? this.userId,
    parentGoalId: parentGoalId.present ? parentGoalId.value : this.parentGoalId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    goalLevel: goalLevel ?? this.goalLevel,
    status: status ?? this.status,
    startDate: startDate.present ? startDate.value : this.startDate,
    targetDate: targetDate.present ? targetDate.value : this.targetDate,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Goal copyWithCompanion(GoalsCompanion data) {
    return Goal(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      originDeviceId: data.originDeviceId.present
          ? data.originDeviceId.value
          : this.originDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      userId: data.userId.present ? data.userId.value : this.userId,
      parentGoalId: data.parentGoalId.present
          ? data.parentGoalId.value
          : this.parentGoalId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      goalLevel: data.goalLevel.present ? data.goalLevel.value : this.goalLevel,
      status: data.status.present ? data.status.value : this.status,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      targetDate: data.targetDate.present
          ? data.targetDate.value
          : this.targetDate,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Goal(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('userId: $userId, ')
          ..write('parentGoalId: $parentGoalId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('goalLevel: $goalLevel, ')
          ..write('status: $status, ')
          ..write('startDate: $startDate, ')
          ..write('targetDate: $targetDate, ')
          ..write('completedAt: $completedAt, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    deletedAt,
    userId,
    parentGoalId,
    title,
    description,
    goalLevel,
    status,
    startDate,
    targetDate,
    completedAt,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Goal &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus &&
          other.serverVersion == this.serverVersion &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.originDeviceId == this.originDeviceId &&
          other.deletedAt == this.deletedAt &&
          other.userId == this.userId &&
          other.parentGoalId == this.parentGoalId &&
          other.title == this.title &&
          other.description == this.description &&
          other.goalLevel == this.goalLevel &&
          other.status == this.status &&
          other.startDate == this.startDate &&
          other.targetDate == this.targetDate &&
          other.completedAt == this.completedAt &&
          other.sortOrder == this.sortOrder);
}

class GoalsCompanion extends UpdateCompanion<Goal> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> syncStatus;
  final Value<int?> serverVersion;
  final Value<int?> lastSyncedAt;
  final Value<String?> originDeviceId;
  final Value<int?> deletedAt;
  final Value<String> userId;
  final Value<String?> parentGoalId;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> goalLevel;
  final Value<String> status;
  final Value<String?> startDate;
  final Value<String?> targetDate;
  final Value<int?> completedAt;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.userId = const Value.absent(),
    this.parentGoalId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.goalLevel = const Value.absent(),
    this.status = const Value.absent(),
    this.startDate = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String userId,
    this.parentGoalId = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    required String goalLevel,
    this.status = const Value.absent(),
    this.startDate = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       title = Value(title),
       goalLevel = Value(goalLevel);
  static Insertable<Goal> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? syncStatus,
    Expression<int>? serverVersion,
    Expression<int>? lastSyncedAt,
    Expression<String>? originDeviceId,
    Expression<int>? deletedAt,
    Expression<String>? userId,
    Expression<String>? parentGoalId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? goalLevel,
    Expression<String>? status,
    Expression<String>? startDate,
    Expression<String>? targetDate,
    Expression<int>? completedAt,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverVersion != null) 'server_version': serverVersion,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (originDeviceId != null) 'origin_device_id': originDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (userId != null) 'user_id': userId,
      if (parentGoalId != null) 'parent_goal_id': parentGoalId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (goalLevel != null) 'goal_level': goalLevel,
      if (status != null) 'status': status,
      if (startDate != null) 'start_date': startDate,
      if (targetDate != null) 'target_date': targetDate,
      if (completedAt != null) 'completed_at': completedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? syncStatus,
    Value<int?>? serverVersion,
    Value<int?>? lastSyncedAt,
    Value<String?>? originDeviceId,
    Value<int?>? deletedAt,
    Value<String>? userId,
    Value<String?>? parentGoalId,
    Value<String>? title,
    Value<String?>? description,
    Value<String>? goalLevel,
    Value<String>? status,
    Value<String?>? startDate,
    Value<String?>? targetDate,
    Value<int?>? completedAt,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return GoalsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      serverVersion: serverVersion ?? this.serverVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      originDeviceId: originDeviceId ?? this.originDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      userId: userId ?? this.userId,
      parentGoalId: parentGoalId ?? this.parentGoalId,
      title: title ?? this.title,
      description: description ?? this.description,
      goalLevel: goalLevel ?? this.goalLevel,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      completedAt: completedAt ?? this.completedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt.value);
    }
    if (originDeviceId.present) {
      map['origin_device_id'] = Variable<String>(originDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (parentGoalId.present) {
      map['parent_goal_id'] = Variable<String>(parentGoalId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (goalLevel.present) {
      map['goal_level'] = Variable<String>(goalLevel.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<String>(targetDate.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('userId: $userId, ')
          ..write('parentGoalId: $parentGoalId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('goalLevel: $goalLevel, ')
          ..write('status: $status, ')
          ..write('startDate: $startDate, ')
          ..write('targetDate: $targetDate, ')
          ..write('completedAt: $completedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodayRecordsTable extends TodayRecords
    with TableInfo<$TodayRecordsTable, TodayRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodayRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: databaseUuid.v4,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncedAt = GeneratedColumn<int>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originDeviceIdMeta = const VerificationMeta(
    'originDeviceId',
  );
  @override
  late final GeneratedColumn<String> originDeviceId = GeneratedColumn<String>(
    'origin_device_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_profiles (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _recordDateMeta = const VerificationMeta(
    'recordDate',
  );
  @override
  late final GeneratedColumn<String> recordDate = GeneratedColumn<String>(
    'record_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timezoneOffsetMinutesMeta =
      const VerificationMeta('timezoneOffsetMinutes');
  @override
  late final GeneratedColumn<int> timezoneOffsetMinutes = GeneratedColumn<int>(
    'timezone_offset_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priority1Meta = const VerificationMeta(
    'priority1',
  );
  @override
  late final GeneratedColumn<String> priority1 = GeneratedColumn<String>(
    'priority_1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priority1CompletedMeta =
      const VerificationMeta('priority1Completed');
  @override
  late final GeneratedColumn<bool> priority1Completed = GeneratedColumn<bool>(
    'priority_1_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("priority_1_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _priority1GoalIdMeta = const VerificationMeta(
    'priority1GoalId',
  );
  @override
  late final GeneratedColumn<String> priority1GoalId = GeneratedColumn<String>(
    'priority_1_goal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _priority2Meta = const VerificationMeta(
    'priority2',
  );
  @override
  late final GeneratedColumn<String> priority2 = GeneratedColumn<String>(
    'priority_2',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priority2CompletedMeta =
      const VerificationMeta('priority2Completed');
  @override
  late final GeneratedColumn<bool> priority2Completed = GeneratedColumn<bool>(
    'priority_2_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("priority_2_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _priority2GoalIdMeta = const VerificationMeta(
    'priority2GoalId',
  );
  @override
  late final GeneratedColumn<String> priority2GoalId = GeneratedColumn<String>(
    'priority_2_goal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _priority3Meta = const VerificationMeta(
    'priority3',
  );
  @override
  late final GeneratedColumn<String> priority3 = GeneratedColumn<String>(
    'priority_3',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priority3CompletedMeta =
      const VerificationMeta('priority3Completed');
  @override
  late final GeneratedColumn<bool> priority3Completed = GeneratedColumn<bool>(
    'priority_3_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("priority_3_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _priority3GoalIdMeta = const VerificationMeta(
    'priority3GoalId',
  );
  @override
  late final GeneratedColumn<String> priority3GoalId = GeneratedColumn<String>(
    'priority_3_goal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _moodScoreMeta = const VerificationMeta(
    'moodScore',
  );
  @override
  late final GeneratedColumn<int> moodScore = GeneratedColumn<int>(
    'mood_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _energyScoreMeta = const VerificationMeta(
    'energyScore',
  );
  @override
  late final GeneratedColumn<int> energyScore = GeneratedColumn<int>(
    'energy_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _researchMinutesMeta = const VerificationMeta(
    'researchMinutes',
  );
  @override
  late final GeneratedColumn<int> researchMinutes = GeneratedColumn<int>(
    'research_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _learningMinutesMeta = const VerificationMeta(
    'learningMinutes',
  );
  @override
  late final GeneratedColumn<int> learningMinutes = GeneratedColumn<int>(
    'learning_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dailyNoteMeta = const VerificationMeta(
    'dailyNote',
  );
  @override
  late final GeneratedColumn<String> dailyNote = GeneratedColumn<String>(
    'daily_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordStatusMeta = const VerificationMeta(
    'recordStatus',
  );
  @override
  late final GeneratedColumn<String> recordStatus = GeneratedColumn<String>(
    'record_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    deletedAt,
    userId,
    recordDate,
    timezoneOffsetMinutes,
    priority1,
    priority1Completed,
    priority1GoalId,
    priority2,
    priority2Completed,
    priority2GoalId,
    priority3,
    priority3Completed,
    priority3GoalId,
    moodScore,
    energyScore,
    researchMinutes,
    learningMinutes,
    dailyNote,
    recordStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'today_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodayRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('origin_device_id')) {
      context.handle(
        _originDeviceIdMeta,
        originDeviceId.isAcceptableOrUnknown(
          data['origin_device_id']!,
          _originDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('record_date')) {
      context.handle(
        _recordDateMeta,
        recordDate.isAcceptableOrUnknown(data['record_date']!, _recordDateMeta),
      );
    } else if (isInserting) {
      context.missing(_recordDateMeta);
    }
    if (data.containsKey('timezone_offset_minutes')) {
      context.handle(
        _timezoneOffsetMinutesMeta,
        timezoneOffsetMinutes.isAcceptableOrUnknown(
          data['timezone_offset_minutes']!,
          _timezoneOffsetMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timezoneOffsetMinutesMeta);
    }
    if (data.containsKey('priority_1')) {
      context.handle(
        _priority1Meta,
        priority1.isAcceptableOrUnknown(data['priority_1']!, _priority1Meta),
      );
    }
    if (data.containsKey('priority_1_completed')) {
      context.handle(
        _priority1CompletedMeta,
        priority1Completed.isAcceptableOrUnknown(
          data['priority_1_completed']!,
          _priority1CompletedMeta,
        ),
      );
    }
    if (data.containsKey('priority_1_goal_id')) {
      context.handle(
        _priority1GoalIdMeta,
        priority1GoalId.isAcceptableOrUnknown(
          data['priority_1_goal_id']!,
          _priority1GoalIdMeta,
        ),
      );
    }
    if (data.containsKey('priority_2')) {
      context.handle(
        _priority2Meta,
        priority2.isAcceptableOrUnknown(data['priority_2']!, _priority2Meta),
      );
    }
    if (data.containsKey('priority_2_completed')) {
      context.handle(
        _priority2CompletedMeta,
        priority2Completed.isAcceptableOrUnknown(
          data['priority_2_completed']!,
          _priority2CompletedMeta,
        ),
      );
    }
    if (data.containsKey('priority_2_goal_id')) {
      context.handle(
        _priority2GoalIdMeta,
        priority2GoalId.isAcceptableOrUnknown(
          data['priority_2_goal_id']!,
          _priority2GoalIdMeta,
        ),
      );
    }
    if (data.containsKey('priority_3')) {
      context.handle(
        _priority3Meta,
        priority3.isAcceptableOrUnknown(data['priority_3']!, _priority3Meta),
      );
    }
    if (data.containsKey('priority_3_completed')) {
      context.handle(
        _priority3CompletedMeta,
        priority3Completed.isAcceptableOrUnknown(
          data['priority_3_completed']!,
          _priority3CompletedMeta,
        ),
      );
    }
    if (data.containsKey('priority_3_goal_id')) {
      context.handle(
        _priority3GoalIdMeta,
        priority3GoalId.isAcceptableOrUnknown(
          data['priority_3_goal_id']!,
          _priority3GoalIdMeta,
        ),
      );
    }
    if (data.containsKey('mood_score')) {
      context.handle(
        _moodScoreMeta,
        moodScore.isAcceptableOrUnknown(data['mood_score']!, _moodScoreMeta),
      );
    }
    if (data.containsKey('energy_score')) {
      context.handle(
        _energyScoreMeta,
        energyScore.isAcceptableOrUnknown(
          data['energy_score']!,
          _energyScoreMeta,
        ),
      );
    }
    if (data.containsKey('research_minutes')) {
      context.handle(
        _researchMinutesMeta,
        researchMinutes.isAcceptableOrUnknown(
          data['research_minutes']!,
          _researchMinutesMeta,
        ),
      );
    }
    if (data.containsKey('learning_minutes')) {
      context.handle(
        _learningMinutesMeta,
        learningMinutes.isAcceptableOrUnknown(
          data['learning_minutes']!,
          _learningMinutesMeta,
        ),
      );
    }
    if (data.containsKey('daily_note')) {
      context.handle(
        _dailyNoteMeta,
        dailyNote.isAcceptableOrUnknown(data['daily_note']!, _dailyNoteMeta),
      );
    }
    if (data.containsKey('record_status')) {
      context.handle(
        _recordStatusMeta,
        recordStatus.isAcceptableOrUnknown(
          data['record_status']!,
          _recordStatusMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodayRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodayRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_at'],
      ),
      originDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      recordDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_date'],
      )!,
      timezoneOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timezone_offset_minutes'],
      )!,
      priority1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority_1'],
      ),
      priority1Completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}priority_1_completed'],
      )!,
      priority1GoalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority_1_goal_id'],
      ),
      priority2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority_2'],
      ),
      priority2Completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}priority_2_completed'],
      )!,
      priority2GoalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority_2_goal_id'],
      ),
      priority3: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority_3'],
      ),
      priority3Completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}priority_3_completed'],
      )!,
      priority3GoalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority_3_goal_id'],
      ),
      moodScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mood_score'],
      ),
      energyScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}energy_score'],
      ),
      researchMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}research_minutes'],
      ),
      learningMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}learning_minutes'],
      ),
      dailyNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}daily_note'],
      ),
      recordStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_status'],
      )!,
    );
  }

  @override
  $TodayRecordsTable createAlias(String alias) {
    return $TodayRecordsTable(attachedDatabase, alias);
  }
}

class TodayRecord extends DataClass implements Insertable<TodayRecord> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;
  final int? serverVersion;
  final int? lastSyncedAt;
  final String? originDeviceId;
  final int? deletedAt;
  final String userId;
  final String recordDate;
  final int timezoneOffsetMinutes;
  final String? priority1;
  final bool priority1Completed;
  final String? priority1GoalId;
  final String? priority2;
  final bool priority2Completed;
  final String? priority2GoalId;
  final String? priority3;
  final bool priority3Completed;
  final String? priority3GoalId;
  final int? moodScore;
  final int? energyScore;
  final int? researchMinutes;
  final int? learningMinutes;
  final String? dailyNote;
  final String recordStatus;
  const TodayRecord({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.serverVersion,
    this.lastSyncedAt,
    this.originDeviceId,
    this.deletedAt,
    required this.userId,
    required this.recordDate,
    required this.timezoneOffsetMinutes,
    this.priority1,
    required this.priority1Completed,
    this.priority1GoalId,
    this.priority2,
    required this.priority2Completed,
    this.priority2GoalId,
    this.priority3,
    required this.priority3Completed,
    this.priority3GoalId,
    this.moodScore,
    this.energyScore,
    this.researchMinutes,
    this.learningMinutes,
    this.dailyNote,
    required this.recordStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || serverVersion != null) {
      map['server_version'] = Variable<int>(serverVersion);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt);
    }
    if (!nullToAbsent || originDeviceId != null) {
      map['origin_device_id'] = Variable<String>(originDeviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['user_id'] = Variable<String>(userId);
    map['record_date'] = Variable<String>(recordDate);
    map['timezone_offset_minutes'] = Variable<int>(timezoneOffsetMinutes);
    if (!nullToAbsent || priority1 != null) {
      map['priority_1'] = Variable<String>(priority1);
    }
    map['priority_1_completed'] = Variable<bool>(priority1Completed);
    if (!nullToAbsent || priority1GoalId != null) {
      map['priority_1_goal_id'] = Variable<String>(priority1GoalId);
    }
    if (!nullToAbsent || priority2 != null) {
      map['priority_2'] = Variable<String>(priority2);
    }
    map['priority_2_completed'] = Variable<bool>(priority2Completed);
    if (!nullToAbsent || priority2GoalId != null) {
      map['priority_2_goal_id'] = Variable<String>(priority2GoalId);
    }
    if (!nullToAbsent || priority3 != null) {
      map['priority_3'] = Variable<String>(priority3);
    }
    map['priority_3_completed'] = Variable<bool>(priority3Completed);
    if (!nullToAbsent || priority3GoalId != null) {
      map['priority_3_goal_id'] = Variable<String>(priority3GoalId);
    }
    if (!nullToAbsent || moodScore != null) {
      map['mood_score'] = Variable<int>(moodScore);
    }
    if (!nullToAbsent || energyScore != null) {
      map['energy_score'] = Variable<int>(energyScore);
    }
    if (!nullToAbsent || researchMinutes != null) {
      map['research_minutes'] = Variable<int>(researchMinutes);
    }
    if (!nullToAbsent || learningMinutes != null) {
      map['learning_minutes'] = Variable<int>(learningMinutes);
    }
    if (!nullToAbsent || dailyNote != null) {
      map['daily_note'] = Variable<String>(dailyNote);
    }
    map['record_status'] = Variable<String>(recordStatus);
    return map;
  }

  TodayRecordsCompanion toCompanion(bool nullToAbsent) {
    return TodayRecordsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
      serverVersion: serverVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(serverVersion),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      originDeviceId: originDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(originDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      userId: Value(userId),
      recordDate: Value(recordDate),
      timezoneOffsetMinutes: Value(timezoneOffsetMinutes),
      priority1: priority1 == null && nullToAbsent
          ? const Value.absent()
          : Value(priority1),
      priority1Completed: Value(priority1Completed),
      priority1GoalId: priority1GoalId == null && nullToAbsent
          ? const Value.absent()
          : Value(priority1GoalId),
      priority2: priority2 == null && nullToAbsent
          ? const Value.absent()
          : Value(priority2),
      priority2Completed: Value(priority2Completed),
      priority2GoalId: priority2GoalId == null && nullToAbsent
          ? const Value.absent()
          : Value(priority2GoalId),
      priority3: priority3 == null && nullToAbsent
          ? const Value.absent()
          : Value(priority3),
      priority3Completed: Value(priority3Completed),
      priority3GoalId: priority3GoalId == null && nullToAbsent
          ? const Value.absent()
          : Value(priority3GoalId),
      moodScore: moodScore == null && nullToAbsent
          ? const Value.absent()
          : Value(moodScore),
      energyScore: energyScore == null && nullToAbsent
          ? const Value.absent()
          : Value(energyScore),
      researchMinutes: researchMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(researchMinutes),
      learningMinutes: learningMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(learningMinutes),
      dailyNote: dailyNote == null && nullToAbsent
          ? const Value.absent()
          : Value(dailyNote),
      recordStatus: Value(recordStatus),
    );
  }

  factory TodayRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodayRecord(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      serverVersion: serializer.fromJson<int?>(json['serverVersion']),
      lastSyncedAt: serializer.fromJson<int?>(json['lastSyncedAt']),
      originDeviceId: serializer.fromJson<String?>(json['originDeviceId']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      userId: serializer.fromJson<String>(json['userId']),
      recordDate: serializer.fromJson<String>(json['recordDate']),
      timezoneOffsetMinutes: serializer.fromJson<int>(
        json['timezoneOffsetMinutes'],
      ),
      priority1: serializer.fromJson<String?>(json['priority1']),
      priority1Completed: serializer.fromJson<bool>(json['priority1Completed']),
      priority1GoalId: serializer.fromJson<String?>(json['priority1GoalId']),
      priority2: serializer.fromJson<String?>(json['priority2']),
      priority2Completed: serializer.fromJson<bool>(json['priority2Completed']),
      priority2GoalId: serializer.fromJson<String?>(json['priority2GoalId']),
      priority3: serializer.fromJson<String?>(json['priority3']),
      priority3Completed: serializer.fromJson<bool>(json['priority3Completed']),
      priority3GoalId: serializer.fromJson<String?>(json['priority3GoalId']),
      moodScore: serializer.fromJson<int?>(json['moodScore']),
      energyScore: serializer.fromJson<int?>(json['energyScore']),
      researchMinutes: serializer.fromJson<int?>(json['researchMinutes']),
      learningMinutes: serializer.fromJson<int?>(json['learningMinutes']),
      dailyNote: serializer.fromJson<String?>(json['dailyNote']),
      recordStatus: serializer.fromJson<String>(json['recordStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'serverVersion': serializer.toJson<int?>(serverVersion),
      'lastSyncedAt': serializer.toJson<int?>(lastSyncedAt),
      'originDeviceId': serializer.toJson<String?>(originDeviceId),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'userId': serializer.toJson<String>(userId),
      'recordDate': serializer.toJson<String>(recordDate),
      'timezoneOffsetMinutes': serializer.toJson<int>(timezoneOffsetMinutes),
      'priority1': serializer.toJson<String?>(priority1),
      'priority1Completed': serializer.toJson<bool>(priority1Completed),
      'priority1GoalId': serializer.toJson<String?>(priority1GoalId),
      'priority2': serializer.toJson<String?>(priority2),
      'priority2Completed': serializer.toJson<bool>(priority2Completed),
      'priority2GoalId': serializer.toJson<String?>(priority2GoalId),
      'priority3': serializer.toJson<String?>(priority3),
      'priority3Completed': serializer.toJson<bool>(priority3Completed),
      'priority3GoalId': serializer.toJson<String?>(priority3GoalId),
      'moodScore': serializer.toJson<int?>(moodScore),
      'energyScore': serializer.toJson<int?>(energyScore),
      'researchMinutes': serializer.toJson<int?>(researchMinutes),
      'learningMinutes': serializer.toJson<int?>(learningMinutes),
      'dailyNote': serializer.toJson<String?>(dailyNote),
      'recordStatus': serializer.toJson<String>(recordStatus),
    };
  }

  TodayRecord copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
    Value<int?> serverVersion = const Value.absent(),
    Value<int?> lastSyncedAt = const Value.absent(),
    Value<String?> originDeviceId = const Value.absent(),
    Value<int?> deletedAt = const Value.absent(),
    String? userId,
    String? recordDate,
    int? timezoneOffsetMinutes,
    Value<String?> priority1 = const Value.absent(),
    bool? priority1Completed,
    Value<String?> priority1GoalId = const Value.absent(),
    Value<String?> priority2 = const Value.absent(),
    bool? priority2Completed,
    Value<String?> priority2GoalId = const Value.absent(),
    Value<String?> priority3 = const Value.absent(),
    bool? priority3Completed,
    Value<String?> priority3GoalId = const Value.absent(),
    Value<int?> moodScore = const Value.absent(),
    Value<int?> energyScore = const Value.absent(),
    Value<int?> researchMinutes = const Value.absent(),
    Value<int?> learningMinutes = const Value.absent(),
    Value<String?> dailyNote = const Value.absent(),
    String? recordStatus,
  }) => TodayRecord(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    serverVersion: serverVersion.present
        ? serverVersion.value
        : this.serverVersion,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    originDeviceId: originDeviceId.present
        ? originDeviceId.value
        : this.originDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    userId: userId ?? this.userId,
    recordDate: recordDate ?? this.recordDate,
    timezoneOffsetMinutes: timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
    priority1: priority1.present ? priority1.value : this.priority1,
    priority1Completed: priority1Completed ?? this.priority1Completed,
    priority1GoalId: priority1GoalId.present
        ? priority1GoalId.value
        : this.priority1GoalId,
    priority2: priority2.present ? priority2.value : this.priority2,
    priority2Completed: priority2Completed ?? this.priority2Completed,
    priority2GoalId: priority2GoalId.present
        ? priority2GoalId.value
        : this.priority2GoalId,
    priority3: priority3.present ? priority3.value : this.priority3,
    priority3Completed: priority3Completed ?? this.priority3Completed,
    priority3GoalId: priority3GoalId.present
        ? priority3GoalId.value
        : this.priority3GoalId,
    moodScore: moodScore.present ? moodScore.value : this.moodScore,
    energyScore: energyScore.present ? energyScore.value : this.energyScore,
    researchMinutes: researchMinutes.present
        ? researchMinutes.value
        : this.researchMinutes,
    learningMinutes: learningMinutes.present
        ? learningMinutes.value
        : this.learningMinutes,
    dailyNote: dailyNote.present ? dailyNote.value : this.dailyNote,
    recordStatus: recordStatus ?? this.recordStatus,
  );
  TodayRecord copyWithCompanion(TodayRecordsCompanion data) {
    return TodayRecord(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      originDeviceId: data.originDeviceId.present
          ? data.originDeviceId.value
          : this.originDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      userId: data.userId.present ? data.userId.value : this.userId,
      recordDate: data.recordDate.present
          ? data.recordDate.value
          : this.recordDate,
      timezoneOffsetMinutes: data.timezoneOffsetMinutes.present
          ? data.timezoneOffsetMinutes.value
          : this.timezoneOffsetMinutes,
      priority1: data.priority1.present ? data.priority1.value : this.priority1,
      priority1Completed: data.priority1Completed.present
          ? data.priority1Completed.value
          : this.priority1Completed,
      priority1GoalId: data.priority1GoalId.present
          ? data.priority1GoalId.value
          : this.priority1GoalId,
      priority2: data.priority2.present ? data.priority2.value : this.priority2,
      priority2Completed: data.priority2Completed.present
          ? data.priority2Completed.value
          : this.priority2Completed,
      priority2GoalId: data.priority2GoalId.present
          ? data.priority2GoalId.value
          : this.priority2GoalId,
      priority3: data.priority3.present ? data.priority3.value : this.priority3,
      priority3Completed: data.priority3Completed.present
          ? data.priority3Completed.value
          : this.priority3Completed,
      priority3GoalId: data.priority3GoalId.present
          ? data.priority3GoalId.value
          : this.priority3GoalId,
      moodScore: data.moodScore.present ? data.moodScore.value : this.moodScore,
      energyScore: data.energyScore.present
          ? data.energyScore.value
          : this.energyScore,
      researchMinutes: data.researchMinutes.present
          ? data.researchMinutes.value
          : this.researchMinutes,
      learningMinutes: data.learningMinutes.present
          ? data.learningMinutes.value
          : this.learningMinutes,
      dailyNote: data.dailyNote.present ? data.dailyNote.value : this.dailyNote,
      recordStatus: data.recordStatus.present
          ? data.recordStatus.value
          : this.recordStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodayRecord(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('userId: $userId, ')
          ..write('recordDate: $recordDate, ')
          ..write('timezoneOffsetMinutes: $timezoneOffsetMinutes, ')
          ..write('priority1: $priority1, ')
          ..write('priority1Completed: $priority1Completed, ')
          ..write('priority1GoalId: $priority1GoalId, ')
          ..write('priority2: $priority2, ')
          ..write('priority2Completed: $priority2Completed, ')
          ..write('priority2GoalId: $priority2GoalId, ')
          ..write('priority3: $priority3, ')
          ..write('priority3Completed: $priority3Completed, ')
          ..write('priority3GoalId: $priority3GoalId, ')
          ..write('moodScore: $moodScore, ')
          ..write('energyScore: $energyScore, ')
          ..write('researchMinutes: $researchMinutes, ')
          ..write('learningMinutes: $learningMinutes, ')
          ..write('dailyNote: $dailyNote, ')
          ..write('recordStatus: $recordStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    deletedAt,
    userId,
    recordDate,
    timezoneOffsetMinutes,
    priority1,
    priority1Completed,
    priority1GoalId,
    priority2,
    priority2Completed,
    priority2GoalId,
    priority3,
    priority3Completed,
    priority3GoalId,
    moodScore,
    energyScore,
    researchMinutes,
    learningMinutes,
    dailyNote,
    recordStatus,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodayRecord &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus &&
          other.serverVersion == this.serverVersion &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.originDeviceId == this.originDeviceId &&
          other.deletedAt == this.deletedAt &&
          other.userId == this.userId &&
          other.recordDate == this.recordDate &&
          other.timezoneOffsetMinutes == this.timezoneOffsetMinutes &&
          other.priority1 == this.priority1 &&
          other.priority1Completed == this.priority1Completed &&
          other.priority1GoalId == this.priority1GoalId &&
          other.priority2 == this.priority2 &&
          other.priority2Completed == this.priority2Completed &&
          other.priority2GoalId == this.priority2GoalId &&
          other.priority3 == this.priority3 &&
          other.priority3Completed == this.priority3Completed &&
          other.priority3GoalId == this.priority3GoalId &&
          other.moodScore == this.moodScore &&
          other.energyScore == this.energyScore &&
          other.researchMinutes == this.researchMinutes &&
          other.learningMinutes == this.learningMinutes &&
          other.dailyNote == this.dailyNote &&
          other.recordStatus == this.recordStatus);
}

class TodayRecordsCompanion extends UpdateCompanion<TodayRecord> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> syncStatus;
  final Value<int?> serverVersion;
  final Value<int?> lastSyncedAt;
  final Value<String?> originDeviceId;
  final Value<int?> deletedAt;
  final Value<String> userId;
  final Value<String> recordDate;
  final Value<int> timezoneOffsetMinutes;
  final Value<String?> priority1;
  final Value<bool> priority1Completed;
  final Value<String?> priority1GoalId;
  final Value<String?> priority2;
  final Value<bool> priority2Completed;
  final Value<String?> priority2GoalId;
  final Value<String?> priority3;
  final Value<bool> priority3Completed;
  final Value<String?> priority3GoalId;
  final Value<int?> moodScore;
  final Value<int?> energyScore;
  final Value<int?> researchMinutes;
  final Value<int?> learningMinutes;
  final Value<String?> dailyNote;
  final Value<String> recordStatus;
  final Value<int> rowid;
  const TodayRecordsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.userId = const Value.absent(),
    this.recordDate = const Value.absent(),
    this.timezoneOffsetMinutes = const Value.absent(),
    this.priority1 = const Value.absent(),
    this.priority1Completed = const Value.absent(),
    this.priority1GoalId = const Value.absent(),
    this.priority2 = const Value.absent(),
    this.priority2Completed = const Value.absent(),
    this.priority2GoalId = const Value.absent(),
    this.priority3 = const Value.absent(),
    this.priority3Completed = const Value.absent(),
    this.priority3GoalId = const Value.absent(),
    this.moodScore = const Value.absent(),
    this.energyScore = const Value.absent(),
    this.researchMinutes = const Value.absent(),
    this.learningMinutes = const Value.absent(),
    this.dailyNote = const Value.absent(),
    this.recordStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodayRecordsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String userId,
    required String recordDate,
    required int timezoneOffsetMinutes,
    this.priority1 = const Value.absent(),
    this.priority1Completed = const Value.absent(),
    this.priority1GoalId = const Value.absent(),
    this.priority2 = const Value.absent(),
    this.priority2Completed = const Value.absent(),
    this.priority2GoalId = const Value.absent(),
    this.priority3 = const Value.absent(),
    this.priority3Completed = const Value.absent(),
    this.priority3GoalId = const Value.absent(),
    this.moodScore = const Value.absent(),
    this.energyScore = const Value.absent(),
    this.researchMinutes = const Value.absent(),
    this.learningMinutes = const Value.absent(),
    this.dailyNote = const Value.absent(),
    this.recordStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       recordDate = Value(recordDate),
       timezoneOffsetMinutes = Value(timezoneOffsetMinutes);
  static Insertable<TodayRecord> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? syncStatus,
    Expression<int>? serverVersion,
    Expression<int>? lastSyncedAt,
    Expression<String>? originDeviceId,
    Expression<int>? deletedAt,
    Expression<String>? userId,
    Expression<String>? recordDate,
    Expression<int>? timezoneOffsetMinutes,
    Expression<String>? priority1,
    Expression<bool>? priority1Completed,
    Expression<String>? priority1GoalId,
    Expression<String>? priority2,
    Expression<bool>? priority2Completed,
    Expression<String>? priority2GoalId,
    Expression<String>? priority3,
    Expression<bool>? priority3Completed,
    Expression<String>? priority3GoalId,
    Expression<int>? moodScore,
    Expression<int>? energyScore,
    Expression<int>? researchMinutes,
    Expression<int>? learningMinutes,
    Expression<String>? dailyNote,
    Expression<String>? recordStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverVersion != null) 'server_version': serverVersion,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (originDeviceId != null) 'origin_device_id': originDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (userId != null) 'user_id': userId,
      if (recordDate != null) 'record_date': recordDate,
      if (timezoneOffsetMinutes != null)
        'timezone_offset_minutes': timezoneOffsetMinutes,
      if (priority1 != null) 'priority_1': priority1,
      if (priority1Completed != null)
        'priority_1_completed': priority1Completed,
      if (priority1GoalId != null) 'priority_1_goal_id': priority1GoalId,
      if (priority2 != null) 'priority_2': priority2,
      if (priority2Completed != null)
        'priority_2_completed': priority2Completed,
      if (priority2GoalId != null) 'priority_2_goal_id': priority2GoalId,
      if (priority3 != null) 'priority_3': priority3,
      if (priority3Completed != null)
        'priority_3_completed': priority3Completed,
      if (priority3GoalId != null) 'priority_3_goal_id': priority3GoalId,
      if (moodScore != null) 'mood_score': moodScore,
      if (energyScore != null) 'energy_score': energyScore,
      if (researchMinutes != null) 'research_minutes': researchMinutes,
      if (learningMinutes != null) 'learning_minutes': learningMinutes,
      if (dailyNote != null) 'daily_note': dailyNote,
      if (recordStatus != null) 'record_status': recordStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodayRecordsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? syncStatus,
    Value<int?>? serverVersion,
    Value<int?>? lastSyncedAt,
    Value<String?>? originDeviceId,
    Value<int?>? deletedAt,
    Value<String>? userId,
    Value<String>? recordDate,
    Value<int>? timezoneOffsetMinutes,
    Value<String?>? priority1,
    Value<bool>? priority1Completed,
    Value<String?>? priority1GoalId,
    Value<String?>? priority2,
    Value<bool>? priority2Completed,
    Value<String?>? priority2GoalId,
    Value<String?>? priority3,
    Value<bool>? priority3Completed,
    Value<String?>? priority3GoalId,
    Value<int?>? moodScore,
    Value<int?>? energyScore,
    Value<int?>? researchMinutes,
    Value<int?>? learningMinutes,
    Value<String?>? dailyNote,
    Value<String>? recordStatus,
    Value<int>? rowid,
  }) {
    return TodayRecordsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      serverVersion: serverVersion ?? this.serverVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      originDeviceId: originDeviceId ?? this.originDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      userId: userId ?? this.userId,
      recordDate: recordDate ?? this.recordDate,
      timezoneOffsetMinutes:
          timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
      priority1: priority1 ?? this.priority1,
      priority1Completed: priority1Completed ?? this.priority1Completed,
      priority1GoalId: priority1GoalId ?? this.priority1GoalId,
      priority2: priority2 ?? this.priority2,
      priority2Completed: priority2Completed ?? this.priority2Completed,
      priority2GoalId: priority2GoalId ?? this.priority2GoalId,
      priority3: priority3 ?? this.priority3,
      priority3Completed: priority3Completed ?? this.priority3Completed,
      priority3GoalId: priority3GoalId ?? this.priority3GoalId,
      moodScore: moodScore ?? this.moodScore,
      energyScore: energyScore ?? this.energyScore,
      researchMinutes: researchMinutes ?? this.researchMinutes,
      learningMinutes: learningMinutes ?? this.learningMinutes,
      dailyNote: dailyNote ?? this.dailyNote,
      recordStatus: recordStatus ?? this.recordStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt.value);
    }
    if (originDeviceId.present) {
      map['origin_device_id'] = Variable<String>(originDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (recordDate.present) {
      map['record_date'] = Variable<String>(recordDate.value);
    }
    if (timezoneOffsetMinutes.present) {
      map['timezone_offset_minutes'] = Variable<int>(
        timezoneOffsetMinutes.value,
      );
    }
    if (priority1.present) {
      map['priority_1'] = Variable<String>(priority1.value);
    }
    if (priority1Completed.present) {
      map['priority_1_completed'] = Variable<bool>(priority1Completed.value);
    }
    if (priority1GoalId.present) {
      map['priority_1_goal_id'] = Variable<String>(priority1GoalId.value);
    }
    if (priority2.present) {
      map['priority_2'] = Variable<String>(priority2.value);
    }
    if (priority2Completed.present) {
      map['priority_2_completed'] = Variable<bool>(priority2Completed.value);
    }
    if (priority2GoalId.present) {
      map['priority_2_goal_id'] = Variable<String>(priority2GoalId.value);
    }
    if (priority3.present) {
      map['priority_3'] = Variable<String>(priority3.value);
    }
    if (priority3Completed.present) {
      map['priority_3_completed'] = Variable<bool>(priority3Completed.value);
    }
    if (priority3GoalId.present) {
      map['priority_3_goal_id'] = Variable<String>(priority3GoalId.value);
    }
    if (moodScore.present) {
      map['mood_score'] = Variable<int>(moodScore.value);
    }
    if (energyScore.present) {
      map['energy_score'] = Variable<int>(energyScore.value);
    }
    if (researchMinutes.present) {
      map['research_minutes'] = Variable<int>(researchMinutes.value);
    }
    if (learningMinutes.present) {
      map['learning_minutes'] = Variable<int>(learningMinutes.value);
    }
    if (dailyNote.present) {
      map['daily_note'] = Variable<String>(dailyNote.value);
    }
    if (recordStatus.present) {
      map['record_status'] = Variable<String>(recordStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodayRecordsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('userId: $userId, ')
          ..write('recordDate: $recordDate, ')
          ..write('timezoneOffsetMinutes: $timezoneOffsetMinutes, ')
          ..write('priority1: $priority1, ')
          ..write('priority1Completed: $priority1Completed, ')
          ..write('priority1GoalId: $priority1GoalId, ')
          ..write('priority2: $priority2, ')
          ..write('priority2Completed: $priority2Completed, ')
          ..write('priority2GoalId: $priority2GoalId, ')
          ..write('priority3: $priority3, ')
          ..write('priority3Completed: $priority3Completed, ')
          ..write('priority3GoalId: $priority3GoalId, ')
          ..write('moodScore: $moodScore, ')
          ..write('energyScore: $energyScore, ')
          ..write('researchMinutes: $researchMinutes, ')
          ..write('learningMinutes: $learningMinutes, ')
          ..write('dailyNote: $dailyNote, ')
          ..write('recordStatus: $recordStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalEntriesTable extends JournalEntries
    with TableInfo<$JournalEntriesTable, JournalEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: databaseUuid.v4,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncedAt = GeneratedColumn<int>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originDeviceIdMeta = const VerificationMeta(
    'originDeviceId',
  );
  @override
  late final GeneratedColumn<String> originDeviceId = GeneratedColumn<String>(
    'origin_device_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_profiles (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _todayRecordIdMeta = const VerificationMeta(
    'todayRecordId',
  );
  @override
  late final GeneratedColumn<String> todayRecordId = GeneratedColumn<String>(
    'today_record_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES today_records (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _entryDateMeta = const VerificationMeta(
    'entryDate',
  );
  @override
  late final GeneratedColumn<String> entryDate = GeneratedColumn<String>(
    'entry_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timezoneOffsetMinutesMeta =
      const VerificationMeta('timezoneOffsetMinutes');
  @override
  late final GeneratedColumn<int> timezoneOffsetMinutes = GeneratedColumn<int>(
    'timezone_offset_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mostImportantAccomplishmentMeta =
      const VerificationMeta('mostImportantAccomplishment');
  @override
  late final GeneratedColumn<String> mostImportantAccomplishment =
      GeneratedColumn<String>(
        'most_important_accomplishment',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _mostDrainingEventMeta = const VerificationMeta(
    'mostDrainingEvent',
  );
  @override
  late final GeneratedColumn<String> mostDrainingEvent =
      GeneratedColumn<String>(
        'most_draining_event',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _emotionSourceMeta = const VerificationMeta(
    'emotionSource',
  );
  @override
  late final GeneratedColumn<String> emotionSource = GeneratedColumn<String>(
    'emotion_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _learningMeta = const VerificationMeta(
    'learning',
  );
  @override
  late final GeneratedColumn<String> learning = GeneratedColumn<String>(
    'learning',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tomorrowAdjustmentMeta =
      const VerificationMeta('tomorrowAdjustment');
  @override
  late final GeneratedColumn<String> tomorrowAdjustment =
      GeneratedColumn<String>(
        'tomorrow_adjustment',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _entryStatusMeta = const VerificationMeta(
    'entryStatus',
  );
  @override
  late final GeneratedColumn<String> entryStatus = GeneratedColumn<String>(
    'entry_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    deletedAt,
    userId,
    todayRecordId,
    entryDate,
    timezoneOffsetMinutes,
    mostImportantAccomplishment,
    mostDrainingEvent,
    emotionSource,
    learning,
    tomorrowAdjustment,
    entryStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<JournalEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('origin_device_id')) {
      context.handle(
        _originDeviceIdMeta,
        originDeviceId.isAcceptableOrUnknown(
          data['origin_device_id']!,
          _originDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('today_record_id')) {
      context.handle(
        _todayRecordIdMeta,
        todayRecordId.isAcceptableOrUnknown(
          data['today_record_id']!,
          _todayRecordIdMeta,
        ),
      );
    }
    if (data.containsKey('entry_date')) {
      context.handle(
        _entryDateMeta,
        entryDate.isAcceptableOrUnknown(data['entry_date']!, _entryDateMeta),
      );
    } else if (isInserting) {
      context.missing(_entryDateMeta);
    }
    if (data.containsKey('timezone_offset_minutes')) {
      context.handle(
        _timezoneOffsetMinutesMeta,
        timezoneOffsetMinutes.isAcceptableOrUnknown(
          data['timezone_offset_minutes']!,
          _timezoneOffsetMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timezoneOffsetMinutesMeta);
    }
    if (data.containsKey('most_important_accomplishment')) {
      context.handle(
        _mostImportantAccomplishmentMeta,
        mostImportantAccomplishment.isAcceptableOrUnknown(
          data['most_important_accomplishment']!,
          _mostImportantAccomplishmentMeta,
        ),
      );
    }
    if (data.containsKey('most_draining_event')) {
      context.handle(
        _mostDrainingEventMeta,
        mostDrainingEvent.isAcceptableOrUnknown(
          data['most_draining_event']!,
          _mostDrainingEventMeta,
        ),
      );
    }
    if (data.containsKey('emotion_source')) {
      context.handle(
        _emotionSourceMeta,
        emotionSource.isAcceptableOrUnknown(
          data['emotion_source']!,
          _emotionSourceMeta,
        ),
      );
    }
    if (data.containsKey('learning')) {
      context.handle(
        _learningMeta,
        learning.isAcceptableOrUnknown(data['learning']!, _learningMeta),
      );
    }
    if (data.containsKey('tomorrow_adjustment')) {
      context.handle(
        _tomorrowAdjustmentMeta,
        tomorrowAdjustment.isAcceptableOrUnknown(
          data['tomorrow_adjustment']!,
          _tomorrowAdjustmentMeta,
        ),
      );
    }
    if (data.containsKey('entry_status')) {
      context.handle(
        _entryStatusMeta,
        entryStatus.isAcceptableOrUnknown(
          data['entry_status']!,
          _entryStatusMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JournalEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_at'],
      ),
      originDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      todayRecordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}today_record_id'],
      ),
      entryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_date'],
      )!,
      timezoneOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timezone_offset_minutes'],
      )!,
      mostImportantAccomplishment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}most_important_accomplishment'],
      ),
      mostDrainingEvent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}most_draining_event'],
      ),
      emotionSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emotion_source'],
      ),
      learning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learning'],
      ),
      tomorrowAdjustment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tomorrow_adjustment'],
      ),
      entryStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_status'],
      )!,
    );
  }

  @override
  $JournalEntriesTable createAlias(String alias) {
    return $JournalEntriesTable(attachedDatabase, alias);
  }
}

class JournalEntry extends DataClass implements Insertable<JournalEntry> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;
  final int? serverVersion;
  final int? lastSyncedAt;
  final String? originDeviceId;
  final int? deletedAt;
  final String userId;
  final String? todayRecordId;
  final String entryDate;
  final int timezoneOffsetMinutes;
  final String? mostImportantAccomplishment;
  final String? mostDrainingEvent;
  final String? emotionSource;
  final String? learning;
  final String? tomorrowAdjustment;
  final String entryStatus;
  const JournalEntry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.serverVersion,
    this.lastSyncedAt,
    this.originDeviceId,
    this.deletedAt,
    required this.userId,
    this.todayRecordId,
    required this.entryDate,
    required this.timezoneOffsetMinutes,
    this.mostImportantAccomplishment,
    this.mostDrainingEvent,
    this.emotionSource,
    this.learning,
    this.tomorrowAdjustment,
    required this.entryStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || serverVersion != null) {
      map['server_version'] = Variable<int>(serverVersion);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt);
    }
    if (!nullToAbsent || originDeviceId != null) {
      map['origin_device_id'] = Variable<String>(originDeviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || todayRecordId != null) {
      map['today_record_id'] = Variable<String>(todayRecordId);
    }
    map['entry_date'] = Variable<String>(entryDate);
    map['timezone_offset_minutes'] = Variable<int>(timezoneOffsetMinutes);
    if (!nullToAbsent || mostImportantAccomplishment != null) {
      map['most_important_accomplishment'] = Variable<String>(
        mostImportantAccomplishment,
      );
    }
    if (!nullToAbsent || mostDrainingEvent != null) {
      map['most_draining_event'] = Variable<String>(mostDrainingEvent);
    }
    if (!nullToAbsent || emotionSource != null) {
      map['emotion_source'] = Variable<String>(emotionSource);
    }
    if (!nullToAbsent || learning != null) {
      map['learning'] = Variable<String>(learning);
    }
    if (!nullToAbsent || tomorrowAdjustment != null) {
      map['tomorrow_adjustment'] = Variable<String>(tomorrowAdjustment);
    }
    map['entry_status'] = Variable<String>(entryStatus);
    return map;
  }

  JournalEntriesCompanion toCompanion(bool nullToAbsent) {
    return JournalEntriesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
      serverVersion: serverVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(serverVersion),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      originDeviceId: originDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(originDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      userId: Value(userId),
      todayRecordId: todayRecordId == null && nullToAbsent
          ? const Value.absent()
          : Value(todayRecordId),
      entryDate: Value(entryDate),
      timezoneOffsetMinutes: Value(timezoneOffsetMinutes),
      mostImportantAccomplishment:
          mostImportantAccomplishment == null && nullToAbsent
          ? const Value.absent()
          : Value(mostImportantAccomplishment),
      mostDrainingEvent: mostDrainingEvent == null && nullToAbsent
          ? const Value.absent()
          : Value(mostDrainingEvent),
      emotionSource: emotionSource == null && nullToAbsent
          ? const Value.absent()
          : Value(emotionSource),
      learning: learning == null && nullToAbsent
          ? const Value.absent()
          : Value(learning),
      tomorrowAdjustment: tomorrowAdjustment == null && nullToAbsent
          ? const Value.absent()
          : Value(tomorrowAdjustment),
      entryStatus: Value(entryStatus),
    );
  }

  factory JournalEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalEntry(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      serverVersion: serializer.fromJson<int?>(json['serverVersion']),
      lastSyncedAt: serializer.fromJson<int?>(json['lastSyncedAt']),
      originDeviceId: serializer.fromJson<String?>(json['originDeviceId']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      userId: serializer.fromJson<String>(json['userId']),
      todayRecordId: serializer.fromJson<String?>(json['todayRecordId']),
      entryDate: serializer.fromJson<String>(json['entryDate']),
      timezoneOffsetMinutes: serializer.fromJson<int>(
        json['timezoneOffsetMinutes'],
      ),
      mostImportantAccomplishment: serializer.fromJson<String?>(
        json['mostImportantAccomplishment'],
      ),
      mostDrainingEvent: serializer.fromJson<String?>(
        json['mostDrainingEvent'],
      ),
      emotionSource: serializer.fromJson<String?>(json['emotionSource']),
      learning: serializer.fromJson<String?>(json['learning']),
      tomorrowAdjustment: serializer.fromJson<String?>(
        json['tomorrowAdjustment'],
      ),
      entryStatus: serializer.fromJson<String>(json['entryStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'serverVersion': serializer.toJson<int?>(serverVersion),
      'lastSyncedAt': serializer.toJson<int?>(lastSyncedAt),
      'originDeviceId': serializer.toJson<String?>(originDeviceId),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'userId': serializer.toJson<String>(userId),
      'todayRecordId': serializer.toJson<String?>(todayRecordId),
      'entryDate': serializer.toJson<String>(entryDate),
      'timezoneOffsetMinutes': serializer.toJson<int>(timezoneOffsetMinutes),
      'mostImportantAccomplishment': serializer.toJson<String?>(
        mostImportantAccomplishment,
      ),
      'mostDrainingEvent': serializer.toJson<String?>(mostDrainingEvent),
      'emotionSource': serializer.toJson<String?>(emotionSource),
      'learning': serializer.toJson<String?>(learning),
      'tomorrowAdjustment': serializer.toJson<String?>(tomorrowAdjustment),
      'entryStatus': serializer.toJson<String>(entryStatus),
    };
  }

  JournalEntry copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
    Value<int?> serverVersion = const Value.absent(),
    Value<int?> lastSyncedAt = const Value.absent(),
    Value<String?> originDeviceId = const Value.absent(),
    Value<int?> deletedAt = const Value.absent(),
    String? userId,
    Value<String?> todayRecordId = const Value.absent(),
    String? entryDate,
    int? timezoneOffsetMinutes,
    Value<String?> mostImportantAccomplishment = const Value.absent(),
    Value<String?> mostDrainingEvent = const Value.absent(),
    Value<String?> emotionSource = const Value.absent(),
    Value<String?> learning = const Value.absent(),
    Value<String?> tomorrowAdjustment = const Value.absent(),
    String? entryStatus,
  }) => JournalEntry(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    serverVersion: serverVersion.present
        ? serverVersion.value
        : this.serverVersion,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    originDeviceId: originDeviceId.present
        ? originDeviceId.value
        : this.originDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    userId: userId ?? this.userId,
    todayRecordId: todayRecordId.present
        ? todayRecordId.value
        : this.todayRecordId,
    entryDate: entryDate ?? this.entryDate,
    timezoneOffsetMinutes: timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
    mostImportantAccomplishment: mostImportantAccomplishment.present
        ? mostImportantAccomplishment.value
        : this.mostImportantAccomplishment,
    mostDrainingEvent: mostDrainingEvent.present
        ? mostDrainingEvent.value
        : this.mostDrainingEvent,
    emotionSource: emotionSource.present
        ? emotionSource.value
        : this.emotionSource,
    learning: learning.present ? learning.value : this.learning,
    tomorrowAdjustment: tomorrowAdjustment.present
        ? tomorrowAdjustment.value
        : this.tomorrowAdjustment,
    entryStatus: entryStatus ?? this.entryStatus,
  );
  JournalEntry copyWithCompanion(JournalEntriesCompanion data) {
    return JournalEntry(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      originDeviceId: data.originDeviceId.present
          ? data.originDeviceId.value
          : this.originDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      userId: data.userId.present ? data.userId.value : this.userId,
      todayRecordId: data.todayRecordId.present
          ? data.todayRecordId.value
          : this.todayRecordId,
      entryDate: data.entryDate.present ? data.entryDate.value : this.entryDate,
      timezoneOffsetMinutes: data.timezoneOffsetMinutes.present
          ? data.timezoneOffsetMinutes.value
          : this.timezoneOffsetMinutes,
      mostImportantAccomplishment: data.mostImportantAccomplishment.present
          ? data.mostImportantAccomplishment.value
          : this.mostImportantAccomplishment,
      mostDrainingEvent: data.mostDrainingEvent.present
          ? data.mostDrainingEvent.value
          : this.mostDrainingEvent,
      emotionSource: data.emotionSource.present
          ? data.emotionSource.value
          : this.emotionSource,
      learning: data.learning.present ? data.learning.value : this.learning,
      tomorrowAdjustment: data.tomorrowAdjustment.present
          ? data.tomorrowAdjustment.value
          : this.tomorrowAdjustment,
      entryStatus: data.entryStatus.present
          ? data.entryStatus.value
          : this.entryStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntry(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('userId: $userId, ')
          ..write('todayRecordId: $todayRecordId, ')
          ..write('entryDate: $entryDate, ')
          ..write('timezoneOffsetMinutes: $timezoneOffsetMinutes, ')
          ..write('mostImportantAccomplishment: $mostImportantAccomplishment, ')
          ..write('mostDrainingEvent: $mostDrainingEvent, ')
          ..write('emotionSource: $emotionSource, ')
          ..write('learning: $learning, ')
          ..write('tomorrowAdjustment: $tomorrowAdjustment, ')
          ..write('entryStatus: $entryStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    deletedAt,
    userId,
    todayRecordId,
    entryDate,
    timezoneOffsetMinutes,
    mostImportantAccomplishment,
    mostDrainingEvent,
    emotionSource,
    learning,
    tomorrowAdjustment,
    entryStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalEntry &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus &&
          other.serverVersion == this.serverVersion &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.originDeviceId == this.originDeviceId &&
          other.deletedAt == this.deletedAt &&
          other.userId == this.userId &&
          other.todayRecordId == this.todayRecordId &&
          other.entryDate == this.entryDate &&
          other.timezoneOffsetMinutes == this.timezoneOffsetMinutes &&
          other.mostImportantAccomplishment ==
              this.mostImportantAccomplishment &&
          other.mostDrainingEvent == this.mostDrainingEvent &&
          other.emotionSource == this.emotionSource &&
          other.learning == this.learning &&
          other.tomorrowAdjustment == this.tomorrowAdjustment &&
          other.entryStatus == this.entryStatus);
}

class JournalEntriesCompanion extends UpdateCompanion<JournalEntry> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> syncStatus;
  final Value<int?> serverVersion;
  final Value<int?> lastSyncedAt;
  final Value<String?> originDeviceId;
  final Value<int?> deletedAt;
  final Value<String> userId;
  final Value<String?> todayRecordId;
  final Value<String> entryDate;
  final Value<int> timezoneOffsetMinutes;
  final Value<String?> mostImportantAccomplishment;
  final Value<String?> mostDrainingEvent;
  final Value<String?> emotionSource;
  final Value<String?> learning;
  final Value<String?> tomorrowAdjustment;
  final Value<String> entryStatus;
  final Value<int> rowid;
  const JournalEntriesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.userId = const Value.absent(),
    this.todayRecordId = const Value.absent(),
    this.entryDate = const Value.absent(),
    this.timezoneOffsetMinutes = const Value.absent(),
    this.mostImportantAccomplishment = const Value.absent(),
    this.mostDrainingEvent = const Value.absent(),
    this.emotionSource = const Value.absent(),
    this.learning = const Value.absent(),
    this.tomorrowAdjustment = const Value.absent(),
    this.entryStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalEntriesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String userId,
    this.todayRecordId = const Value.absent(),
    required String entryDate,
    required int timezoneOffsetMinutes,
    this.mostImportantAccomplishment = const Value.absent(),
    this.mostDrainingEvent = const Value.absent(),
    this.emotionSource = const Value.absent(),
    this.learning = const Value.absent(),
    this.tomorrowAdjustment = const Value.absent(),
    this.entryStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       entryDate = Value(entryDate),
       timezoneOffsetMinutes = Value(timezoneOffsetMinutes);
  static Insertable<JournalEntry> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? syncStatus,
    Expression<int>? serverVersion,
    Expression<int>? lastSyncedAt,
    Expression<String>? originDeviceId,
    Expression<int>? deletedAt,
    Expression<String>? userId,
    Expression<String>? todayRecordId,
    Expression<String>? entryDate,
    Expression<int>? timezoneOffsetMinutes,
    Expression<String>? mostImportantAccomplishment,
    Expression<String>? mostDrainingEvent,
    Expression<String>? emotionSource,
    Expression<String>? learning,
    Expression<String>? tomorrowAdjustment,
    Expression<String>? entryStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverVersion != null) 'server_version': serverVersion,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (originDeviceId != null) 'origin_device_id': originDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (userId != null) 'user_id': userId,
      if (todayRecordId != null) 'today_record_id': todayRecordId,
      if (entryDate != null) 'entry_date': entryDate,
      if (timezoneOffsetMinutes != null)
        'timezone_offset_minutes': timezoneOffsetMinutes,
      if (mostImportantAccomplishment != null)
        'most_important_accomplishment': mostImportantAccomplishment,
      if (mostDrainingEvent != null) 'most_draining_event': mostDrainingEvent,
      if (emotionSource != null) 'emotion_source': emotionSource,
      if (learning != null) 'learning': learning,
      if (tomorrowAdjustment != null) 'tomorrow_adjustment': tomorrowAdjustment,
      if (entryStatus != null) 'entry_status': entryStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalEntriesCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? syncStatus,
    Value<int?>? serverVersion,
    Value<int?>? lastSyncedAt,
    Value<String?>? originDeviceId,
    Value<int?>? deletedAt,
    Value<String>? userId,
    Value<String?>? todayRecordId,
    Value<String>? entryDate,
    Value<int>? timezoneOffsetMinutes,
    Value<String?>? mostImportantAccomplishment,
    Value<String?>? mostDrainingEvent,
    Value<String?>? emotionSource,
    Value<String?>? learning,
    Value<String?>? tomorrowAdjustment,
    Value<String>? entryStatus,
    Value<int>? rowid,
  }) {
    return JournalEntriesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      serverVersion: serverVersion ?? this.serverVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      originDeviceId: originDeviceId ?? this.originDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      userId: userId ?? this.userId,
      todayRecordId: todayRecordId ?? this.todayRecordId,
      entryDate: entryDate ?? this.entryDate,
      timezoneOffsetMinutes:
          timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
      mostImportantAccomplishment:
          mostImportantAccomplishment ?? this.mostImportantAccomplishment,
      mostDrainingEvent: mostDrainingEvent ?? this.mostDrainingEvent,
      emotionSource: emotionSource ?? this.emotionSource,
      learning: learning ?? this.learning,
      tomorrowAdjustment: tomorrowAdjustment ?? this.tomorrowAdjustment,
      entryStatus: entryStatus ?? this.entryStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt.value);
    }
    if (originDeviceId.present) {
      map['origin_device_id'] = Variable<String>(originDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (todayRecordId.present) {
      map['today_record_id'] = Variable<String>(todayRecordId.value);
    }
    if (entryDate.present) {
      map['entry_date'] = Variable<String>(entryDate.value);
    }
    if (timezoneOffsetMinutes.present) {
      map['timezone_offset_minutes'] = Variable<int>(
        timezoneOffsetMinutes.value,
      );
    }
    if (mostImportantAccomplishment.present) {
      map['most_important_accomplishment'] = Variable<String>(
        mostImportantAccomplishment.value,
      );
    }
    if (mostDrainingEvent.present) {
      map['most_draining_event'] = Variable<String>(mostDrainingEvent.value);
    }
    if (emotionSource.present) {
      map['emotion_source'] = Variable<String>(emotionSource.value);
    }
    if (learning.present) {
      map['learning'] = Variable<String>(learning.value);
    }
    if (tomorrowAdjustment.present) {
      map['tomorrow_adjustment'] = Variable<String>(tomorrowAdjustment.value);
    }
    if (entryStatus.present) {
      map['entry_status'] = Variable<String>(entryStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntriesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('userId: $userId, ')
          ..write('todayRecordId: $todayRecordId, ')
          ..write('entryDate: $entryDate, ')
          ..write('timezoneOffsetMinutes: $timezoneOffsetMinutes, ')
          ..write('mostImportantAccomplishment: $mostImportantAccomplishment, ')
          ..write('mostDrainingEvent: $mostDrainingEvent, ')
          ..write('emotionSource: $emotionSource, ')
          ..write('learning: $learning, ')
          ..write('tomorrowAdjustment: $tomorrowAdjustment, ')
          ..write('entryStatus: $entryStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HealthRecordsTable extends HealthRecords
    with TableInfo<$HealthRecordsTable, HealthRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HealthRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: databaseUuid.v4,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncedAt = GeneratedColumn<int>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originDeviceIdMeta = const VerificationMeta(
    'originDeviceId',
  );
  @override
  late final GeneratedColumn<String> originDeviceId = GeneratedColumn<String>(
    'origin_device_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_profiles (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _todayRecordIdMeta = const VerificationMeta(
    'todayRecordId',
  );
  @override
  late final GeneratedColumn<String> todayRecordId = GeneratedColumn<String>(
    'today_record_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES today_records (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _recordDateMeta = const VerificationMeta(
    'recordDate',
  );
  @override
  late final GeneratedColumn<String> recordDate = GeneratedColumn<String>(
    'record_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timezoneOffsetMinutesMeta =
      const VerificationMeta('timezoneOffsetMinutes');
  @override
  late final GeneratedColumn<int> timezoneOffsetMinutes = GeneratedColumn<int>(
    'timezone_offset_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sleepDurationMinutesMeta =
      const VerificationMeta('sleepDurationMinutes');
  @override
  late final GeneratedColumn<int> sleepDurationMinutes = GeneratedColumn<int>(
    'sleep_duration_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _waterIntakeMlMeta = const VerificationMeta(
    'waterIntakeMl',
  );
  @override
  late final GeneratedColumn<int> waterIntakeMl = GeneratedColumn<int>(
    'water_intake_ml',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exerciseTypeMeta = const VerificationMeta(
    'exerciseType',
  );
  @override
  late final GeneratedColumn<String> exerciseType = GeneratedColumn<String>(
    'exercise_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exerciseDurationMinutesMeta =
      const VerificationMeta('exerciseDurationMinutes');
  @override
  late final GeneratedColumn<int> exerciseDurationMinutes =
      GeneratedColumn<int>(
        'exercise_duration_minutes',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _physicalStateScoreMeta =
      const VerificationMeta('physicalStateScore');
  @override
  late final GeneratedColumn<int> physicalStateScore = GeneratedColumn<int>(
    'physical_state_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataSourceMeta = const VerificationMeta(
    'dataSource',
  );
  @override
  late final GeneratedColumn<String> dataSource = GeneratedColumn<String>(
    'data_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _sourceRecordIdMeta = const VerificationMeta(
    'sourceRecordId',
  );
  @override
  late final GeneratedColumn<String> sourceRecordId = GeneratedColumn<String>(
    'source_record_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    deletedAt,
    userId,
    todayRecordId,
    recordDate,
    timezoneOffsetMinutes,
    sleepDurationMinutes,
    weightKg,
    waterIntakeMl,
    exerciseType,
    exerciseDurationMinutes,
    physicalStateScore,
    note,
    dataSource,
    sourceRecordId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'health_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<HealthRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('origin_device_id')) {
      context.handle(
        _originDeviceIdMeta,
        originDeviceId.isAcceptableOrUnknown(
          data['origin_device_id']!,
          _originDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('today_record_id')) {
      context.handle(
        _todayRecordIdMeta,
        todayRecordId.isAcceptableOrUnknown(
          data['today_record_id']!,
          _todayRecordIdMeta,
        ),
      );
    }
    if (data.containsKey('record_date')) {
      context.handle(
        _recordDateMeta,
        recordDate.isAcceptableOrUnknown(data['record_date']!, _recordDateMeta),
      );
    } else if (isInserting) {
      context.missing(_recordDateMeta);
    }
    if (data.containsKey('timezone_offset_minutes')) {
      context.handle(
        _timezoneOffsetMinutesMeta,
        timezoneOffsetMinutes.isAcceptableOrUnknown(
          data['timezone_offset_minutes']!,
          _timezoneOffsetMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timezoneOffsetMinutesMeta);
    }
    if (data.containsKey('sleep_duration_minutes')) {
      context.handle(
        _sleepDurationMinutesMeta,
        sleepDurationMinutes.isAcceptableOrUnknown(
          data['sleep_duration_minutes']!,
          _sleepDurationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    }
    if (data.containsKey('water_intake_ml')) {
      context.handle(
        _waterIntakeMlMeta,
        waterIntakeMl.isAcceptableOrUnknown(
          data['water_intake_ml']!,
          _waterIntakeMlMeta,
        ),
      );
    }
    if (data.containsKey('exercise_type')) {
      context.handle(
        _exerciseTypeMeta,
        exerciseType.isAcceptableOrUnknown(
          data['exercise_type']!,
          _exerciseTypeMeta,
        ),
      );
    }
    if (data.containsKey('exercise_duration_minutes')) {
      context.handle(
        _exerciseDurationMinutesMeta,
        exerciseDurationMinutes.isAcceptableOrUnknown(
          data['exercise_duration_minutes']!,
          _exerciseDurationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('physical_state_score')) {
      context.handle(
        _physicalStateScoreMeta,
        physicalStateScore.isAcceptableOrUnknown(
          data['physical_state_score']!,
          _physicalStateScoreMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('data_source')) {
      context.handle(
        _dataSourceMeta,
        dataSource.isAcceptableOrUnknown(data['data_source']!, _dataSourceMeta),
      );
    }
    if (data.containsKey('source_record_id')) {
      context.handle(
        _sourceRecordIdMeta,
        sourceRecordId.isAcceptableOrUnknown(
          data['source_record_id']!,
          _sourceRecordIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HealthRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HealthRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_at'],
      ),
      originDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      todayRecordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}today_record_id'],
      ),
      recordDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_date'],
      )!,
      timezoneOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timezone_offset_minutes'],
      )!,
      sleepDurationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sleep_duration_minutes'],
      ),
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      ),
      waterIntakeMl: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}water_intake_ml'],
      ),
      exerciseType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_type'],
      ),
      exerciseDurationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_duration_minutes'],
      ),
      physicalStateScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}physical_state_score'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      dataSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_source'],
      )!,
      sourceRecordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_record_id'],
      ),
    );
  }

  @override
  $HealthRecordsTable createAlias(String alias) {
    return $HealthRecordsTable(attachedDatabase, alias);
  }
}

class HealthRecord extends DataClass implements Insertable<HealthRecord> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;
  final int? serverVersion;
  final int? lastSyncedAt;
  final String? originDeviceId;
  final int? deletedAt;
  final String userId;
  final String? todayRecordId;
  final String recordDate;
  final int timezoneOffsetMinutes;
  final int? sleepDurationMinutes;
  final double? weightKg;
  final int? waterIntakeMl;
  final String? exerciseType;
  final int? exerciseDurationMinutes;
  final int? physicalStateScore;
  final String? note;
  final String dataSource;
  final String? sourceRecordId;
  const HealthRecord({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.serverVersion,
    this.lastSyncedAt,
    this.originDeviceId,
    this.deletedAt,
    required this.userId,
    this.todayRecordId,
    required this.recordDate,
    required this.timezoneOffsetMinutes,
    this.sleepDurationMinutes,
    this.weightKg,
    this.waterIntakeMl,
    this.exerciseType,
    this.exerciseDurationMinutes,
    this.physicalStateScore,
    this.note,
    required this.dataSource,
    this.sourceRecordId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || serverVersion != null) {
      map['server_version'] = Variable<int>(serverVersion);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt);
    }
    if (!nullToAbsent || originDeviceId != null) {
      map['origin_device_id'] = Variable<String>(originDeviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || todayRecordId != null) {
      map['today_record_id'] = Variable<String>(todayRecordId);
    }
    map['record_date'] = Variable<String>(recordDate);
    map['timezone_offset_minutes'] = Variable<int>(timezoneOffsetMinutes);
    if (!nullToAbsent || sleepDurationMinutes != null) {
      map['sleep_duration_minutes'] = Variable<int>(sleepDurationMinutes);
    }
    if (!nullToAbsent || weightKg != null) {
      map['weight_kg'] = Variable<double>(weightKg);
    }
    if (!nullToAbsent || waterIntakeMl != null) {
      map['water_intake_ml'] = Variable<int>(waterIntakeMl);
    }
    if (!nullToAbsent || exerciseType != null) {
      map['exercise_type'] = Variable<String>(exerciseType);
    }
    if (!nullToAbsent || exerciseDurationMinutes != null) {
      map['exercise_duration_minutes'] = Variable<int>(exerciseDurationMinutes);
    }
    if (!nullToAbsent || physicalStateScore != null) {
      map['physical_state_score'] = Variable<int>(physicalStateScore);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['data_source'] = Variable<String>(dataSource);
    if (!nullToAbsent || sourceRecordId != null) {
      map['source_record_id'] = Variable<String>(sourceRecordId);
    }
    return map;
  }

  HealthRecordsCompanion toCompanion(bool nullToAbsent) {
    return HealthRecordsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
      serverVersion: serverVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(serverVersion),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      originDeviceId: originDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(originDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      userId: Value(userId),
      todayRecordId: todayRecordId == null && nullToAbsent
          ? const Value.absent()
          : Value(todayRecordId),
      recordDate: Value(recordDate),
      timezoneOffsetMinutes: Value(timezoneOffsetMinutes),
      sleepDurationMinutes: sleepDurationMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(sleepDurationMinutes),
      weightKg: weightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weightKg),
      waterIntakeMl: waterIntakeMl == null && nullToAbsent
          ? const Value.absent()
          : Value(waterIntakeMl),
      exerciseType: exerciseType == null && nullToAbsent
          ? const Value.absent()
          : Value(exerciseType),
      exerciseDurationMinutes: exerciseDurationMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(exerciseDurationMinutes),
      physicalStateScore: physicalStateScore == null && nullToAbsent
          ? const Value.absent()
          : Value(physicalStateScore),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      dataSource: Value(dataSource),
      sourceRecordId: sourceRecordId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRecordId),
    );
  }

  factory HealthRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HealthRecord(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      serverVersion: serializer.fromJson<int?>(json['serverVersion']),
      lastSyncedAt: serializer.fromJson<int?>(json['lastSyncedAt']),
      originDeviceId: serializer.fromJson<String?>(json['originDeviceId']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      userId: serializer.fromJson<String>(json['userId']),
      todayRecordId: serializer.fromJson<String?>(json['todayRecordId']),
      recordDate: serializer.fromJson<String>(json['recordDate']),
      timezoneOffsetMinutes: serializer.fromJson<int>(
        json['timezoneOffsetMinutes'],
      ),
      sleepDurationMinutes: serializer.fromJson<int?>(
        json['sleepDurationMinutes'],
      ),
      weightKg: serializer.fromJson<double?>(json['weightKg']),
      waterIntakeMl: serializer.fromJson<int?>(json['waterIntakeMl']),
      exerciseType: serializer.fromJson<String?>(json['exerciseType']),
      exerciseDurationMinutes: serializer.fromJson<int?>(
        json['exerciseDurationMinutes'],
      ),
      physicalStateScore: serializer.fromJson<int?>(json['physicalStateScore']),
      note: serializer.fromJson<String?>(json['note']),
      dataSource: serializer.fromJson<String>(json['dataSource']),
      sourceRecordId: serializer.fromJson<String?>(json['sourceRecordId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'serverVersion': serializer.toJson<int?>(serverVersion),
      'lastSyncedAt': serializer.toJson<int?>(lastSyncedAt),
      'originDeviceId': serializer.toJson<String?>(originDeviceId),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'userId': serializer.toJson<String>(userId),
      'todayRecordId': serializer.toJson<String?>(todayRecordId),
      'recordDate': serializer.toJson<String>(recordDate),
      'timezoneOffsetMinutes': serializer.toJson<int>(timezoneOffsetMinutes),
      'sleepDurationMinutes': serializer.toJson<int?>(sleepDurationMinutes),
      'weightKg': serializer.toJson<double?>(weightKg),
      'waterIntakeMl': serializer.toJson<int?>(waterIntakeMl),
      'exerciseType': serializer.toJson<String?>(exerciseType),
      'exerciseDurationMinutes': serializer.toJson<int?>(
        exerciseDurationMinutes,
      ),
      'physicalStateScore': serializer.toJson<int?>(physicalStateScore),
      'note': serializer.toJson<String?>(note),
      'dataSource': serializer.toJson<String>(dataSource),
      'sourceRecordId': serializer.toJson<String?>(sourceRecordId),
    };
  }

  HealthRecord copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
    Value<int?> serverVersion = const Value.absent(),
    Value<int?> lastSyncedAt = const Value.absent(),
    Value<String?> originDeviceId = const Value.absent(),
    Value<int?> deletedAt = const Value.absent(),
    String? userId,
    Value<String?> todayRecordId = const Value.absent(),
    String? recordDate,
    int? timezoneOffsetMinutes,
    Value<int?> sleepDurationMinutes = const Value.absent(),
    Value<double?> weightKg = const Value.absent(),
    Value<int?> waterIntakeMl = const Value.absent(),
    Value<String?> exerciseType = const Value.absent(),
    Value<int?> exerciseDurationMinutes = const Value.absent(),
    Value<int?> physicalStateScore = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? dataSource,
    Value<String?> sourceRecordId = const Value.absent(),
  }) => HealthRecord(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    serverVersion: serverVersion.present
        ? serverVersion.value
        : this.serverVersion,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    originDeviceId: originDeviceId.present
        ? originDeviceId.value
        : this.originDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    userId: userId ?? this.userId,
    todayRecordId: todayRecordId.present
        ? todayRecordId.value
        : this.todayRecordId,
    recordDate: recordDate ?? this.recordDate,
    timezoneOffsetMinutes: timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
    sleepDurationMinutes: sleepDurationMinutes.present
        ? sleepDurationMinutes.value
        : this.sleepDurationMinutes,
    weightKg: weightKg.present ? weightKg.value : this.weightKg,
    waterIntakeMl: waterIntakeMl.present
        ? waterIntakeMl.value
        : this.waterIntakeMl,
    exerciseType: exerciseType.present ? exerciseType.value : this.exerciseType,
    exerciseDurationMinutes: exerciseDurationMinutes.present
        ? exerciseDurationMinutes.value
        : this.exerciseDurationMinutes,
    physicalStateScore: physicalStateScore.present
        ? physicalStateScore.value
        : this.physicalStateScore,
    note: note.present ? note.value : this.note,
    dataSource: dataSource ?? this.dataSource,
    sourceRecordId: sourceRecordId.present
        ? sourceRecordId.value
        : this.sourceRecordId,
  );
  HealthRecord copyWithCompanion(HealthRecordsCompanion data) {
    return HealthRecord(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      originDeviceId: data.originDeviceId.present
          ? data.originDeviceId.value
          : this.originDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      userId: data.userId.present ? data.userId.value : this.userId,
      todayRecordId: data.todayRecordId.present
          ? data.todayRecordId.value
          : this.todayRecordId,
      recordDate: data.recordDate.present
          ? data.recordDate.value
          : this.recordDate,
      timezoneOffsetMinutes: data.timezoneOffsetMinutes.present
          ? data.timezoneOffsetMinutes.value
          : this.timezoneOffsetMinutes,
      sleepDurationMinutes: data.sleepDurationMinutes.present
          ? data.sleepDurationMinutes.value
          : this.sleepDurationMinutes,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      waterIntakeMl: data.waterIntakeMl.present
          ? data.waterIntakeMl.value
          : this.waterIntakeMl,
      exerciseType: data.exerciseType.present
          ? data.exerciseType.value
          : this.exerciseType,
      exerciseDurationMinutes: data.exerciseDurationMinutes.present
          ? data.exerciseDurationMinutes.value
          : this.exerciseDurationMinutes,
      physicalStateScore: data.physicalStateScore.present
          ? data.physicalStateScore.value
          : this.physicalStateScore,
      note: data.note.present ? data.note.value : this.note,
      dataSource: data.dataSource.present
          ? data.dataSource.value
          : this.dataSource,
      sourceRecordId: data.sourceRecordId.present
          ? data.sourceRecordId.value
          : this.sourceRecordId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HealthRecord(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('userId: $userId, ')
          ..write('todayRecordId: $todayRecordId, ')
          ..write('recordDate: $recordDate, ')
          ..write('timezoneOffsetMinutes: $timezoneOffsetMinutes, ')
          ..write('sleepDurationMinutes: $sleepDurationMinutes, ')
          ..write('weightKg: $weightKg, ')
          ..write('waterIntakeMl: $waterIntakeMl, ')
          ..write('exerciseType: $exerciseType, ')
          ..write('exerciseDurationMinutes: $exerciseDurationMinutes, ')
          ..write('physicalStateScore: $physicalStateScore, ')
          ..write('note: $note, ')
          ..write('dataSource: $dataSource, ')
          ..write('sourceRecordId: $sourceRecordId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    deletedAt,
    userId,
    todayRecordId,
    recordDate,
    timezoneOffsetMinutes,
    sleepDurationMinutes,
    weightKg,
    waterIntakeMl,
    exerciseType,
    exerciseDurationMinutes,
    physicalStateScore,
    note,
    dataSource,
    sourceRecordId,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HealthRecord &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus &&
          other.serverVersion == this.serverVersion &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.originDeviceId == this.originDeviceId &&
          other.deletedAt == this.deletedAt &&
          other.userId == this.userId &&
          other.todayRecordId == this.todayRecordId &&
          other.recordDate == this.recordDate &&
          other.timezoneOffsetMinutes == this.timezoneOffsetMinutes &&
          other.sleepDurationMinutes == this.sleepDurationMinutes &&
          other.weightKg == this.weightKg &&
          other.waterIntakeMl == this.waterIntakeMl &&
          other.exerciseType == this.exerciseType &&
          other.exerciseDurationMinutes == this.exerciseDurationMinutes &&
          other.physicalStateScore == this.physicalStateScore &&
          other.note == this.note &&
          other.dataSource == this.dataSource &&
          other.sourceRecordId == this.sourceRecordId);
}

class HealthRecordsCompanion extends UpdateCompanion<HealthRecord> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> syncStatus;
  final Value<int?> serverVersion;
  final Value<int?> lastSyncedAt;
  final Value<String?> originDeviceId;
  final Value<int?> deletedAt;
  final Value<String> userId;
  final Value<String?> todayRecordId;
  final Value<String> recordDate;
  final Value<int> timezoneOffsetMinutes;
  final Value<int?> sleepDurationMinutes;
  final Value<double?> weightKg;
  final Value<int?> waterIntakeMl;
  final Value<String?> exerciseType;
  final Value<int?> exerciseDurationMinutes;
  final Value<int?> physicalStateScore;
  final Value<String?> note;
  final Value<String> dataSource;
  final Value<String?> sourceRecordId;
  final Value<int> rowid;
  const HealthRecordsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.userId = const Value.absent(),
    this.todayRecordId = const Value.absent(),
    this.recordDate = const Value.absent(),
    this.timezoneOffsetMinutes = const Value.absent(),
    this.sleepDurationMinutes = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.waterIntakeMl = const Value.absent(),
    this.exerciseType = const Value.absent(),
    this.exerciseDurationMinutes = const Value.absent(),
    this.physicalStateScore = const Value.absent(),
    this.note = const Value.absent(),
    this.dataSource = const Value.absent(),
    this.sourceRecordId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HealthRecordsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String userId,
    this.todayRecordId = const Value.absent(),
    required String recordDate,
    required int timezoneOffsetMinutes,
    this.sleepDurationMinutes = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.waterIntakeMl = const Value.absent(),
    this.exerciseType = const Value.absent(),
    this.exerciseDurationMinutes = const Value.absent(),
    this.physicalStateScore = const Value.absent(),
    this.note = const Value.absent(),
    this.dataSource = const Value.absent(),
    this.sourceRecordId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       recordDate = Value(recordDate),
       timezoneOffsetMinutes = Value(timezoneOffsetMinutes);
  static Insertable<HealthRecord> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? syncStatus,
    Expression<int>? serverVersion,
    Expression<int>? lastSyncedAt,
    Expression<String>? originDeviceId,
    Expression<int>? deletedAt,
    Expression<String>? userId,
    Expression<String>? todayRecordId,
    Expression<String>? recordDate,
    Expression<int>? timezoneOffsetMinutes,
    Expression<int>? sleepDurationMinutes,
    Expression<double>? weightKg,
    Expression<int>? waterIntakeMl,
    Expression<String>? exerciseType,
    Expression<int>? exerciseDurationMinutes,
    Expression<int>? physicalStateScore,
    Expression<String>? note,
    Expression<String>? dataSource,
    Expression<String>? sourceRecordId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverVersion != null) 'server_version': serverVersion,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (originDeviceId != null) 'origin_device_id': originDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (userId != null) 'user_id': userId,
      if (todayRecordId != null) 'today_record_id': todayRecordId,
      if (recordDate != null) 'record_date': recordDate,
      if (timezoneOffsetMinutes != null)
        'timezone_offset_minutes': timezoneOffsetMinutes,
      if (sleepDurationMinutes != null)
        'sleep_duration_minutes': sleepDurationMinutes,
      if (weightKg != null) 'weight_kg': weightKg,
      if (waterIntakeMl != null) 'water_intake_ml': waterIntakeMl,
      if (exerciseType != null) 'exercise_type': exerciseType,
      if (exerciseDurationMinutes != null)
        'exercise_duration_minutes': exerciseDurationMinutes,
      if (physicalStateScore != null)
        'physical_state_score': physicalStateScore,
      if (note != null) 'note': note,
      if (dataSource != null) 'data_source': dataSource,
      if (sourceRecordId != null) 'source_record_id': sourceRecordId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HealthRecordsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? syncStatus,
    Value<int?>? serverVersion,
    Value<int?>? lastSyncedAt,
    Value<String?>? originDeviceId,
    Value<int?>? deletedAt,
    Value<String>? userId,
    Value<String?>? todayRecordId,
    Value<String>? recordDate,
    Value<int>? timezoneOffsetMinutes,
    Value<int?>? sleepDurationMinutes,
    Value<double?>? weightKg,
    Value<int?>? waterIntakeMl,
    Value<String?>? exerciseType,
    Value<int?>? exerciseDurationMinutes,
    Value<int?>? physicalStateScore,
    Value<String?>? note,
    Value<String>? dataSource,
    Value<String?>? sourceRecordId,
    Value<int>? rowid,
  }) {
    return HealthRecordsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      serverVersion: serverVersion ?? this.serverVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      originDeviceId: originDeviceId ?? this.originDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      userId: userId ?? this.userId,
      todayRecordId: todayRecordId ?? this.todayRecordId,
      recordDate: recordDate ?? this.recordDate,
      timezoneOffsetMinutes:
          timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
      sleepDurationMinutes: sleepDurationMinutes ?? this.sleepDurationMinutes,
      weightKg: weightKg ?? this.weightKg,
      waterIntakeMl: waterIntakeMl ?? this.waterIntakeMl,
      exerciseType: exerciseType ?? this.exerciseType,
      exerciseDurationMinutes:
          exerciseDurationMinutes ?? this.exerciseDurationMinutes,
      physicalStateScore: physicalStateScore ?? this.physicalStateScore,
      note: note ?? this.note,
      dataSource: dataSource ?? this.dataSource,
      sourceRecordId: sourceRecordId ?? this.sourceRecordId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt.value);
    }
    if (originDeviceId.present) {
      map['origin_device_id'] = Variable<String>(originDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (todayRecordId.present) {
      map['today_record_id'] = Variable<String>(todayRecordId.value);
    }
    if (recordDate.present) {
      map['record_date'] = Variable<String>(recordDate.value);
    }
    if (timezoneOffsetMinutes.present) {
      map['timezone_offset_minutes'] = Variable<int>(
        timezoneOffsetMinutes.value,
      );
    }
    if (sleepDurationMinutes.present) {
      map['sleep_duration_minutes'] = Variable<int>(sleepDurationMinutes.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (waterIntakeMl.present) {
      map['water_intake_ml'] = Variable<int>(waterIntakeMl.value);
    }
    if (exerciseType.present) {
      map['exercise_type'] = Variable<String>(exerciseType.value);
    }
    if (exerciseDurationMinutes.present) {
      map['exercise_duration_minutes'] = Variable<int>(
        exerciseDurationMinutes.value,
      );
    }
    if (physicalStateScore.present) {
      map['physical_state_score'] = Variable<int>(physicalStateScore.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (dataSource.present) {
      map['data_source'] = Variable<String>(dataSource.value);
    }
    if (sourceRecordId.present) {
      map['source_record_id'] = Variable<String>(sourceRecordId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HealthRecordsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('userId: $userId, ')
          ..write('todayRecordId: $todayRecordId, ')
          ..write('recordDate: $recordDate, ')
          ..write('timezoneOffsetMinutes: $timezoneOffsetMinutes, ')
          ..write('sleepDurationMinutes: $sleepDurationMinutes, ')
          ..write('weightKg: $weightKg, ')
          ..write('waterIntakeMl: $waterIntakeMl, ')
          ..write('exerciseType: $exerciseType, ')
          ..write('exerciseDurationMinutes: $exerciseDurationMinutes, ')
          ..write('physicalStateScore: $physicalStateScore, ')
          ..write('note: $note, ')
          ..write('dataSource: $dataSource, ')
          ..write('sourceRecordId: $sourceRecordId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiReportsTable extends AiReports
    with TableInfo<$AiReportsTable, AiReport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiReportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: databaseUuid.v4,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: utcNowMilliseconds,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local_only'),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncedAt = GeneratedColumn<int>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originDeviceIdMeta = const VerificationMeta(
    'originDeviceId',
  );
  @override
  late final GeneratedColumn<String> originDeviceId = GeneratedColumn<String>(
    'origin_device_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 36,
      maxTextLength: 36,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_profiles (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _reportTypeMeta = const VerificationMeta(
    'reportType',
  );
  @override
  late final GeneratedColumn<String> reportType = GeneratedColumn<String>(
    'report_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodStartDateMeta = const VerificationMeta(
    'periodStartDate',
  );
  @override
  late final GeneratedColumn<String> periodStartDate = GeneratedColumn<String>(
    'period_start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodEndDateMeta = const VerificationMeta(
    'periodEndDate',
  );
  @override
  late final GeneratedColumn<String> periodEndDate = GeneratedColumn<String>(
    'period_end_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputSourcesJsonMeta = const VerificationMeta(
    'inputSourcesJson',
  );
  @override
  late final GeneratedColumn<String> inputSourcesJson = GeneratedColumn<String>(
    'input_sources_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _inputHashMeta = const VerificationMeta(
    'inputHash',
  );
  @override
  late final GeneratedColumn<String> inputHash = GeneratedColumn<String>(
    'input_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputSnapshotJsonMeta = const VerificationMeta(
    'inputSnapshotJson',
  );
  @override
  late final GeneratedColumn<String> inputSnapshotJson =
      GeneratedColumn<String>(
        'input_snapshot_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _promptVersionMeta = const VerificationMeta(
    'promptVersion',
  );
  @override
  late final GeneratedColumn<String> promptVersion = GeneratedColumn<String>(
    'prompt_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _generationModeMeta = const VerificationMeta(
    'generationMode',
  );
  @override
  late final GeneratedColumn<String> generationMode = GeneratedColumn<String>(
    'generation_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _reportStatusMeta = const VerificationMeta(
    'reportStatus',
  );
  @override
  late final GeneratedColumn<String> reportStatus = GeneratedColumn<String>(
    'report_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _reportContentMeta = const VerificationMeta(
    'reportContent',
  );
  @override
  late final GeneratedColumn<String> reportContent = GeneratedColumn<String>(
    'report_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _structuredOutputJsonMeta =
      const VerificationMeta('structuredOutputJson');
  @override
  late final GeneratedColumn<String> structuredOutputJson =
      GeneratedColumn<String>(
        'structured_output_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestedAtMeta = const VerificationMeta(
    'requestedAt',
  );
  @override
  late final GeneratedColumn<int> requestedAt = GeneratedColumn<int>(
    'requested_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<int> generatedAt = GeneratedColumn<int>(
    'generated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    deletedAt,
    userId,
    reportType,
    periodStartDate,
    periodEndDate,
    inputSourcesJson,
    inputHash,
    inputSnapshotJson,
    promptVersion,
    provider,
    model,
    generationMode,
    reportStatus,
    reportContent,
    structuredOutputJson,
    errorCode,
    requestedAt,
    generatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_reports';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiReport> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('origin_device_id')) {
      context.handle(
        _originDeviceIdMeta,
        originDeviceId.isAcceptableOrUnknown(
          data['origin_device_id']!,
          _originDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('report_type')) {
      context.handle(
        _reportTypeMeta,
        reportType.isAcceptableOrUnknown(data['report_type']!, _reportTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_reportTypeMeta);
    }
    if (data.containsKey('period_start_date')) {
      context.handle(
        _periodStartDateMeta,
        periodStartDate.isAcceptableOrUnknown(
          data['period_start_date']!,
          _periodStartDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_periodStartDateMeta);
    }
    if (data.containsKey('period_end_date')) {
      context.handle(
        _periodEndDateMeta,
        periodEndDate.isAcceptableOrUnknown(
          data['period_end_date']!,
          _periodEndDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_periodEndDateMeta);
    }
    if (data.containsKey('input_sources_json')) {
      context.handle(
        _inputSourcesJsonMeta,
        inputSourcesJson.isAcceptableOrUnknown(
          data['input_sources_json']!,
          _inputSourcesJsonMeta,
        ),
      );
    }
    if (data.containsKey('input_hash')) {
      context.handle(
        _inputHashMeta,
        inputHash.isAcceptableOrUnknown(data['input_hash']!, _inputHashMeta),
      );
    } else if (isInserting) {
      context.missing(_inputHashMeta);
    }
    if (data.containsKey('input_snapshot_json')) {
      context.handle(
        _inputSnapshotJsonMeta,
        inputSnapshotJson.isAcceptableOrUnknown(
          data['input_snapshot_json']!,
          _inputSnapshotJsonMeta,
        ),
      );
    }
    if (data.containsKey('prompt_version')) {
      context.handle(
        _promptVersionMeta,
        promptVersion.isAcceptableOrUnknown(
          data['prompt_version']!,
          _promptVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_promptVersionMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('generation_mode')) {
      context.handle(
        _generationModeMeta,
        generationMode.isAcceptableOrUnknown(
          data['generation_mode']!,
          _generationModeMeta,
        ),
      );
    }
    if (data.containsKey('report_status')) {
      context.handle(
        _reportStatusMeta,
        reportStatus.isAcceptableOrUnknown(
          data['report_status']!,
          _reportStatusMeta,
        ),
      );
    }
    if (data.containsKey('report_content')) {
      context.handle(
        _reportContentMeta,
        reportContent.isAcceptableOrUnknown(
          data['report_content']!,
          _reportContentMeta,
        ),
      );
    }
    if (data.containsKey('structured_output_json')) {
      context.handle(
        _structuredOutputJsonMeta,
        structuredOutputJson.isAcceptableOrUnknown(
          data['structured_output_json']!,
          _structuredOutputJsonMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('requested_at')) {
      context.handle(
        _requestedAtMeta,
        requestedAt.isAcceptableOrUnknown(
          data['requested_at']!,
          _requestedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestedAtMeta);
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiReport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiReport(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_at'],
      ),
      originDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      reportType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}report_type'],
      )!,
      periodStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_start_date'],
      )!,
      periodEndDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_end_date'],
      )!,
      inputSourcesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_sources_json'],
      )!,
      inputHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_hash'],
      )!,
      inputSnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_snapshot_json'],
      ),
      promptVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_version'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      generationMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generation_mode'],
      )!,
      reportStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}report_status'],
      )!,
      reportContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}report_content'],
      ),
      structuredOutputJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}structured_output_json'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      requestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}requested_at'],
      )!,
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generated_at'],
      ),
    );
  }

  @override
  $AiReportsTable createAlias(String alias) {
    return $AiReportsTable(attachedDatabase, alias);
  }
}

class AiReport extends DataClass implements Insertable<AiReport> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;
  final int? serverVersion;
  final int? lastSyncedAt;
  final String? originDeviceId;
  final int? deletedAt;
  final String userId;
  final String reportType;
  final String periodStartDate;
  final String periodEndDate;
  final String inputSourcesJson;
  final String inputHash;
  final String? inputSnapshotJson;
  final String promptVersion;
  final String? provider;
  final String? model;
  final String generationMode;
  final String reportStatus;
  final String? reportContent;
  final String? structuredOutputJson;
  final String? errorCode;
  final int requestedAt;
  final int? generatedAt;
  const AiReport({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.serverVersion,
    this.lastSyncedAt,
    this.originDeviceId,
    this.deletedAt,
    required this.userId,
    required this.reportType,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.inputSourcesJson,
    required this.inputHash,
    this.inputSnapshotJson,
    required this.promptVersion,
    this.provider,
    this.model,
    required this.generationMode,
    required this.reportStatus,
    this.reportContent,
    this.structuredOutputJson,
    this.errorCode,
    required this.requestedAt,
    this.generatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || serverVersion != null) {
      map['server_version'] = Variable<int>(serverVersion);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt);
    }
    if (!nullToAbsent || originDeviceId != null) {
      map['origin_device_id'] = Variable<String>(originDeviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['user_id'] = Variable<String>(userId);
    map['report_type'] = Variable<String>(reportType);
    map['period_start_date'] = Variable<String>(periodStartDate);
    map['period_end_date'] = Variable<String>(periodEndDate);
    map['input_sources_json'] = Variable<String>(inputSourcesJson);
    map['input_hash'] = Variable<String>(inputHash);
    if (!nullToAbsent || inputSnapshotJson != null) {
      map['input_snapshot_json'] = Variable<String>(inputSnapshotJson);
    }
    map['prompt_version'] = Variable<String>(promptVersion);
    if (!nullToAbsent || provider != null) {
      map['provider'] = Variable<String>(provider);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    map['generation_mode'] = Variable<String>(generationMode);
    map['report_status'] = Variable<String>(reportStatus);
    if (!nullToAbsent || reportContent != null) {
      map['report_content'] = Variable<String>(reportContent);
    }
    if (!nullToAbsent || structuredOutputJson != null) {
      map['structured_output_json'] = Variable<String>(structuredOutputJson);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    map['requested_at'] = Variable<int>(requestedAt);
    if (!nullToAbsent || generatedAt != null) {
      map['generated_at'] = Variable<int>(generatedAt);
    }
    return map;
  }

  AiReportsCompanion toCompanion(bool nullToAbsent) {
    return AiReportsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
      serverVersion: serverVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(serverVersion),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      originDeviceId: originDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(originDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      userId: Value(userId),
      reportType: Value(reportType),
      periodStartDate: Value(periodStartDate),
      periodEndDate: Value(periodEndDate),
      inputSourcesJson: Value(inputSourcesJson),
      inputHash: Value(inputHash),
      inputSnapshotJson: inputSnapshotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(inputSnapshotJson),
      promptVersion: Value(promptVersion),
      provider: provider == null && nullToAbsent
          ? const Value.absent()
          : Value(provider),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      generationMode: Value(generationMode),
      reportStatus: Value(reportStatus),
      reportContent: reportContent == null && nullToAbsent
          ? const Value.absent()
          : Value(reportContent),
      structuredOutputJson: structuredOutputJson == null && nullToAbsent
          ? const Value.absent()
          : Value(structuredOutputJson),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      requestedAt: Value(requestedAt),
      generatedAt: generatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(generatedAt),
    );
  }

  factory AiReport.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiReport(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      serverVersion: serializer.fromJson<int?>(json['serverVersion']),
      lastSyncedAt: serializer.fromJson<int?>(json['lastSyncedAt']),
      originDeviceId: serializer.fromJson<String?>(json['originDeviceId']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      userId: serializer.fromJson<String>(json['userId']),
      reportType: serializer.fromJson<String>(json['reportType']),
      periodStartDate: serializer.fromJson<String>(json['periodStartDate']),
      periodEndDate: serializer.fromJson<String>(json['periodEndDate']),
      inputSourcesJson: serializer.fromJson<String>(json['inputSourcesJson']),
      inputHash: serializer.fromJson<String>(json['inputHash']),
      inputSnapshotJson: serializer.fromJson<String?>(
        json['inputSnapshotJson'],
      ),
      promptVersion: serializer.fromJson<String>(json['promptVersion']),
      provider: serializer.fromJson<String?>(json['provider']),
      model: serializer.fromJson<String?>(json['model']),
      generationMode: serializer.fromJson<String>(json['generationMode']),
      reportStatus: serializer.fromJson<String>(json['reportStatus']),
      reportContent: serializer.fromJson<String?>(json['reportContent']),
      structuredOutputJson: serializer.fromJson<String?>(
        json['structuredOutputJson'],
      ),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      requestedAt: serializer.fromJson<int>(json['requestedAt']),
      generatedAt: serializer.fromJson<int?>(json['generatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'serverVersion': serializer.toJson<int?>(serverVersion),
      'lastSyncedAt': serializer.toJson<int?>(lastSyncedAt),
      'originDeviceId': serializer.toJson<String?>(originDeviceId),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'userId': serializer.toJson<String>(userId),
      'reportType': serializer.toJson<String>(reportType),
      'periodStartDate': serializer.toJson<String>(periodStartDate),
      'periodEndDate': serializer.toJson<String>(periodEndDate),
      'inputSourcesJson': serializer.toJson<String>(inputSourcesJson),
      'inputHash': serializer.toJson<String>(inputHash),
      'inputSnapshotJson': serializer.toJson<String?>(inputSnapshotJson),
      'promptVersion': serializer.toJson<String>(promptVersion),
      'provider': serializer.toJson<String?>(provider),
      'model': serializer.toJson<String?>(model),
      'generationMode': serializer.toJson<String>(generationMode),
      'reportStatus': serializer.toJson<String>(reportStatus),
      'reportContent': serializer.toJson<String?>(reportContent),
      'structuredOutputJson': serializer.toJson<String?>(structuredOutputJson),
      'errorCode': serializer.toJson<String?>(errorCode),
      'requestedAt': serializer.toJson<int>(requestedAt),
      'generatedAt': serializer.toJson<int?>(generatedAt),
    };
  }

  AiReport copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
    Value<int?> serverVersion = const Value.absent(),
    Value<int?> lastSyncedAt = const Value.absent(),
    Value<String?> originDeviceId = const Value.absent(),
    Value<int?> deletedAt = const Value.absent(),
    String? userId,
    String? reportType,
    String? periodStartDate,
    String? periodEndDate,
    String? inputSourcesJson,
    String? inputHash,
    Value<String?> inputSnapshotJson = const Value.absent(),
    String? promptVersion,
    Value<String?> provider = const Value.absent(),
    Value<String?> model = const Value.absent(),
    String? generationMode,
    String? reportStatus,
    Value<String?> reportContent = const Value.absent(),
    Value<String?> structuredOutputJson = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    int? requestedAt,
    Value<int?> generatedAt = const Value.absent(),
  }) => AiReport(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    serverVersion: serverVersion.present
        ? serverVersion.value
        : this.serverVersion,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    originDeviceId: originDeviceId.present
        ? originDeviceId.value
        : this.originDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    userId: userId ?? this.userId,
    reportType: reportType ?? this.reportType,
    periodStartDate: periodStartDate ?? this.periodStartDate,
    periodEndDate: periodEndDate ?? this.periodEndDate,
    inputSourcesJson: inputSourcesJson ?? this.inputSourcesJson,
    inputHash: inputHash ?? this.inputHash,
    inputSnapshotJson: inputSnapshotJson.present
        ? inputSnapshotJson.value
        : this.inputSnapshotJson,
    promptVersion: promptVersion ?? this.promptVersion,
    provider: provider.present ? provider.value : this.provider,
    model: model.present ? model.value : this.model,
    generationMode: generationMode ?? this.generationMode,
    reportStatus: reportStatus ?? this.reportStatus,
    reportContent: reportContent.present
        ? reportContent.value
        : this.reportContent,
    structuredOutputJson: structuredOutputJson.present
        ? structuredOutputJson.value
        : this.structuredOutputJson,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    requestedAt: requestedAt ?? this.requestedAt,
    generatedAt: generatedAt.present ? generatedAt.value : this.generatedAt,
  );
  AiReport copyWithCompanion(AiReportsCompanion data) {
    return AiReport(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      originDeviceId: data.originDeviceId.present
          ? data.originDeviceId.value
          : this.originDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      userId: data.userId.present ? data.userId.value : this.userId,
      reportType: data.reportType.present
          ? data.reportType.value
          : this.reportType,
      periodStartDate: data.periodStartDate.present
          ? data.periodStartDate.value
          : this.periodStartDate,
      periodEndDate: data.periodEndDate.present
          ? data.periodEndDate.value
          : this.periodEndDate,
      inputSourcesJson: data.inputSourcesJson.present
          ? data.inputSourcesJson.value
          : this.inputSourcesJson,
      inputHash: data.inputHash.present ? data.inputHash.value : this.inputHash,
      inputSnapshotJson: data.inputSnapshotJson.present
          ? data.inputSnapshotJson.value
          : this.inputSnapshotJson,
      promptVersion: data.promptVersion.present
          ? data.promptVersion.value
          : this.promptVersion,
      provider: data.provider.present ? data.provider.value : this.provider,
      model: data.model.present ? data.model.value : this.model,
      generationMode: data.generationMode.present
          ? data.generationMode.value
          : this.generationMode,
      reportStatus: data.reportStatus.present
          ? data.reportStatus.value
          : this.reportStatus,
      reportContent: data.reportContent.present
          ? data.reportContent.value
          : this.reportContent,
      structuredOutputJson: data.structuredOutputJson.present
          ? data.structuredOutputJson.value
          : this.structuredOutputJson,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      requestedAt: data.requestedAt.present
          ? data.requestedAt.value
          : this.requestedAt,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiReport(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('userId: $userId, ')
          ..write('reportType: $reportType, ')
          ..write('periodStartDate: $periodStartDate, ')
          ..write('periodEndDate: $periodEndDate, ')
          ..write('inputSourcesJson: $inputSourcesJson, ')
          ..write('inputHash: $inputHash, ')
          ..write('inputSnapshotJson: $inputSnapshotJson, ')
          ..write('promptVersion: $promptVersion, ')
          ..write('provider: $provider, ')
          ..write('model: $model, ')
          ..write('generationMode: $generationMode, ')
          ..write('reportStatus: $reportStatus, ')
          ..write('reportContent: $reportContent, ')
          ..write('structuredOutputJson: $structuredOutputJson, ')
          ..write('errorCode: $errorCode, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('generatedAt: $generatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    updatedAt,
    syncStatus,
    serverVersion,
    lastSyncedAt,
    originDeviceId,
    deletedAt,
    userId,
    reportType,
    periodStartDate,
    periodEndDate,
    inputSourcesJson,
    inputHash,
    inputSnapshotJson,
    promptVersion,
    provider,
    model,
    generationMode,
    reportStatus,
    reportContent,
    structuredOutputJson,
    errorCode,
    requestedAt,
    generatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiReport &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus &&
          other.serverVersion == this.serverVersion &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.originDeviceId == this.originDeviceId &&
          other.deletedAt == this.deletedAt &&
          other.userId == this.userId &&
          other.reportType == this.reportType &&
          other.periodStartDate == this.periodStartDate &&
          other.periodEndDate == this.periodEndDate &&
          other.inputSourcesJson == this.inputSourcesJson &&
          other.inputHash == this.inputHash &&
          other.inputSnapshotJson == this.inputSnapshotJson &&
          other.promptVersion == this.promptVersion &&
          other.provider == this.provider &&
          other.model == this.model &&
          other.generationMode == this.generationMode &&
          other.reportStatus == this.reportStatus &&
          other.reportContent == this.reportContent &&
          other.structuredOutputJson == this.structuredOutputJson &&
          other.errorCode == this.errorCode &&
          other.requestedAt == this.requestedAt &&
          other.generatedAt == this.generatedAt);
}

class AiReportsCompanion extends UpdateCompanion<AiReport> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> syncStatus;
  final Value<int?> serverVersion;
  final Value<int?> lastSyncedAt;
  final Value<String?> originDeviceId;
  final Value<int?> deletedAt;
  final Value<String> userId;
  final Value<String> reportType;
  final Value<String> periodStartDate;
  final Value<String> periodEndDate;
  final Value<String> inputSourcesJson;
  final Value<String> inputHash;
  final Value<String?> inputSnapshotJson;
  final Value<String> promptVersion;
  final Value<String?> provider;
  final Value<String?> model;
  final Value<String> generationMode;
  final Value<String> reportStatus;
  final Value<String?> reportContent;
  final Value<String?> structuredOutputJson;
  final Value<String?> errorCode;
  final Value<int> requestedAt;
  final Value<int?> generatedAt;
  final Value<int> rowid;
  const AiReportsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.userId = const Value.absent(),
    this.reportType = const Value.absent(),
    this.periodStartDate = const Value.absent(),
    this.periodEndDate = const Value.absent(),
    this.inputSourcesJson = const Value.absent(),
    this.inputHash = const Value.absent(),
    this.inputSnapshotJson = const Value.absent(),
    this.promptVersion = const Value.absent(),
    this.provider = const Value.absent(),
    this.model = const Value.absent(),
    this.generationMode = const Value.absent(),
    this.reportStatus = const Value.absent(),
    this.reportContent = const Value.absent(),
    this.structuredOutputJson = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.requestedAt = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiReportsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String userId,
    required String reportType,
    required String periodStartDate,
    required String periodEndDate,
    this.inputSourcesJson = const Value.absent(),
    required String inputHash,
    this.inputSnapshotJson = const Value.absent(),
    required String promptVersion,
    this.provider = const Value.absent(),
    this.model = const Value.absent(),
    this.generationMode = const Value.absent(),
    this.reportStatus = const Value.absent(),
    this.reportContent = const Value.absent(),
    this.structuredOutputJson = const Value.absent(),
    this.errorCode = const Value.absent(),
    required int requestedAt,
    this.generatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       reportType = Value(reportType),
       periodStartDate = Value(periodStartDate),
       periodEndDate = Value(periodEndDate),
       inputHash = Value(inputHash),
       promptVersion = Value(promptVersion),
       requestedAt = Value(requestedAt);
  static Insertable<AiReport> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? syncStatus,
    Expression<int>? serverVersion,
    Expression<int>? lastSyncedAt,
    Expression<String>? originDeviceId,
    Expression<int>? deletedAt,
    Expression<String>? userId,
    Expression<String>? reportType,
    Expression<String>? periodStartDate,
    Expression<String>? periodEndDate,
    Expression<String>? inputSourcesJson,
    Expression<String>? inputHash,
    Expression<String>? inputSnapshotJson,
    Expression<String>? promptVersion,
    Expression<String>? provider,
    Expression<String>? model,
    Expression<String>? generationMode,
    Expression<String>? reportStatus,
    Expression<String>? reportContent,
    Expression<String>? structuredOutputJson,
    Expression<String>? errorCode,
    Expression<int>? requestedAt,
    Expression<int>? generatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverVersion != null) 'server_version': serverVersion,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (originDeviceId != null) 'origin_device_id': originDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (userId != null) 'user_id': userId,
      if (reportType != null) 'report_type': reportType,
      if (periodStartDate != null) 'period_start_date': periodStartDate,
      if (periodEndDate != null) 'period_end_date': periodEndDate,
      if (inputSourcesJson != null) 'input_sources_json': inputSourcesJson,
      if (inputHash != null) 'input_hash': inputHash,
      if (inputSnapshotJson != null) 'input_snapshot_json': inputSnapshotJson,
      if (promptVersion != null) 'prompt_version': promptVersion,
      if (provider != null) 'provider': provider,
      if (model != null) 'model': model,
      if (generationMode != null) 'generation_mode': generationMode,
      if (reportStatus != null) 'report_status': reportStatus,
      if (reportContent != null) 'report_content': reportContent,
      if (structuredOutputJson != null)
        'structured_output_json': structuredOutputJson,
      if (errorCode != null) 'error_code': errorCode,
      if (requestedAt != null) 'requested_at': requestedAt,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiReportsCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? syncStatus,
    Value<int?>? serverVersion,
    Value<int?>? lastSyncedAt,
    Value<String?>? originDeviceId,
    Value<int?>? deletedAt,
    Value<String>? userId,
    Value<String>? reportType,
    Value<String>? periodStartDate,
    Value<String>? periodEndDate,
    Value<String>? inputSourcesJson,
    Value<String>? inputHash,
    Value<String?>? inputSnapshotJson,
    Value<String>? promptVersion,
    Value<String?>? provider,
    Value<String?>? model,
    Value<String>? generationMode,
    Value<String>? reportStatus,
    Value<String?>? reportContent,
    Value<String?>? structuredOutputJson,
    Value<String?>? errorCode,
    Value<int>? requestedAt,
    Value<int?>? generatedAt,
    Value<int>? rowid,
  }) {
    return AiReportsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      serverVersion: serverVersion ?? this.serverVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      originDeviceId: originDeviceId ?? this.originDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      userId: userId ?? this.userId,
      reportType: reportType ?? this.reportType,
      periodStartDate: periodStartDate ?? this.periodStartDate,
      periodEndDate: periodEndDate ?? this.periodEndDate,
      inputSourcesJson: inputSourcesJson ?? this.inputSourcesJson,
      inputHash: inputHash ?? this.inputHash,
      inputSnapshotJson: inputSnapshotJson ?? this.inputSnapshotJson,
      promptVersion: promptVersion ?? this.promptVersion,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      generationMode: generationMode ?? this.generationMode,
      reportStatus: reportStatus ?? this.reportStatus,
      reportContent: reportContent ?? this.reportContent,
      structuredOutputJson: structuredOutputJson ?? this.structuredOutputJson,
      errorCode: errorCode ?? this.errorCode,
      requestedAt: requestedAt ?? this.requestedAt,
      generatedAt: generatedAt ?? this.generatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<int>(lastSyncedAt.value);
    }
    if (originDeviceId.present) {
      map['origin_device_id'] = Variable<String>(originDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (reportType.present) {
      map['report_type'] = Variable<String>(reportType.value);
    }
    if (periodStartDate.present) {
      map['period_start_date'] = Variable<String>(periodStartDate.value);
    }
    if (periodEndDate.present) {
      map['period_end_date'] = Variable<String>(periodEndDate.value);
    }
    if (inputSourcesJson.present) {
      map['input_sources_json'] = Variable<String>(inputSourcesJson.value);
    }
    if (inputHash.present) {
      map['input_hash'] = Variable<String>(inputHash.value);
    }
    if (inputSnapshotJson.present) {
      map['input_snapshot_json'] = Variable<String>(inputSnapshotJson.value);
    }
    if (promptVersion.present) {
      map['prompt_version'] = Variable<String>(promptVersion.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (generationMode.present) {
      map['generation_mode'] = Variable<String>(generationMode.value);
    }
    if (reportStatus.present) {
      map['report_status'] = Variable<String>(reportStatus.value);
    }
    if (reportContent.present) {
      map['report_content'] = Variable<String>(reportContent.value);
    }
    if (structuredOutputJson.present) {
      map['structured_output_json'] = Variable<String>(
        structuredOutputJson.value,
      );
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (requestedAt.present) {
      map['requested_at'] = Variable<int>(requestedAt.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<int>(generatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiReportsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('userId: $userId, ')
          ..write('reportType: $reportType, ')
          ..write('periodStartDate: $periodStartDate, ')
          ..write('periodEndDate: $periodEndDate, ')
          ..write('inputSourcesJson: $inputSourcesJson, ')
          ..write('inputHash: $inputHash, ')
          ..write('inputSnapshotJson: $inputSnapshotJson, ')
          ..write('promptVersion: $promptVersion, ')
          ..write('provider: $provider, ')
          ..write('model: $model, ')
          ..write('generationMode: $generationMode, ')
          ..write('reportStatus: $reportStatus, ')
          ..write('reportContent: $reportContent, ')
          ..write('structuredOutputJson: $structuredOutputJson, ')
          ..write('errorCode: $errorCode, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $TodayRecordsTable todayRecords = $TodayRecordsTable(this);
  late final $JournalEntriesTable journalEntries = $JournalEntriesTable(this);
  late final $HealthRecordsTable healthRecords = $HealthRecordsTable(this);
  late final $AiReportsTable aiReports = $AiReportsTable(this);
  late final BootstrapDao bootstrapDao = BootstrapDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userProfiles,
    appSettings,
    goals,
    todayRecords,
    journalEntries,
    healthRecords,
    aiReports,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'goals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('goals', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'goals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('today_records', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'goals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('today_records', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'goals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('today_records', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'today_records',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('journal_entries', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'today_records',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('health_records', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      Value<int?> deletedAt,
      Value<String?> displayName,
      Value<String?> growthFocus,
      required String timezoneId,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      Value<int?> deletedAt,
      Value<String?> displayName,
      Value<String?> growthFocus,
      Value<String> timezoneId,
      Value<bool> isActive,
      Value<int> rowid,
    });

final class $$UserProfilesTableReferences
    extends BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile> {
  $$UserProfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AppSettingsTable, List<AppSetting>>
  _appSettingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.appSettings,
    aliasName: 'user_profiles__id__app_settings__user_id',
  );

  $$AppSettingsTableProcessedTableManager get appSettingsRefs {
    final manager = $$AppSettingsTableTableManager(
      $_db,
      $_db.appSettings,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_appSettingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GoalsTable, List<Goal>> _goalsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.goals,
    aliasName: 'user_profiles__id__goals__user_id',
  );

  $$GoalsTableProcessedTableManager get goalsRefs {
    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_goalsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TodayRecordsTable, List<TodayRecord>>
  _todayRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.todayRecords,
    aliasName: 'user_profiles__id__today_records__user_id',
  );

  $$TodayRecordsTableProcessedTableManager get todayRecordsRefs {
    final manager = $$TodayRecordsTableTableManager(
      $_db,
      $_db.todayRecords,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_todayRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$JournalEntriesTable, List<JournalEntry>>
  _journalEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.journalEntries,
    aliasName: 'user_profiles__id__journal_entries__user_id',
  );

  $$JournalEntriesTableProcessedTableManager get journalEntriesRefs {
    final manager = $$JournalEntriesTableTableManager(
      $_db,
      $_db.journalEntries,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_journalEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$HealthRecordsTable, List<HealthRecord>>
  _healthRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.healthRecords,
    aliasName: 'user_profiles__id__health_records__user_id',
  );

  $$HealthRecordsTableProcessedTableManager get healthRecordsRefs {
    final manager = $$HealthRecordsTableTableManager(
      $_db,
      $_db.healthRecords,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_healthRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AiReportsTable, List<AiReport>>
  _aiReportsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.aiReports,
    aliasName: 'user_profiles__id__ai_reports__user_id',
  );

  $$AiReportsTableProcessedTableManager get aiReportsRefs {
    final manager = $$AiReportsTableTableManager(
      $_db,
      $_db.aiReports,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_aiReportsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get growthFocus => $composableBuilder(
    column: $table.growthFocus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> appSettingsRefs(
    Expression<bool> Function($$AppSettingsTableFilterComposer f) f,
  ) {
    final $$AppSettingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.appSettings,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppSettingsTableFilterComposer(
            $db: $db,
            $table: $db.appSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> goalsRefs(
    Expression<bool> Function($$GoalsTableFilterComposer f) f,
  ) {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> todayRecordsRefs(
    Expression<bool> Function($$TodayRecordsTableFilterComposer f) f,
  ) {
    final $$TodayRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableFilterComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> journalEntriesRefs(
    Expression<bool> Function($$JournalEntriesTableFilterComposer f) f,
  ) {
    final $$JournalEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableFilterComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> healthRecordsRefs(
    Expression<bool> Function($$HealthRecordsTableFilterComposer f) f,
  ) {
    final $$HealthRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.healthRecords,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HealthRecordsTableFilterComposer(
            $db: $db,
            $table: $db.healthRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> aiReportsRefs(
    Expression<bool> Function($$AiReportsTableFilterComposer f) f,
  ) {
    final $$AiReportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiReports,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiReportsTableFilterComposer(
            $db: $db,
            $table: $db.aiReports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get growthFocus => $composableBuilder(
    column: $table.growthFocus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get growthFocus => $composableBuilder(
    column: $table.growthFocus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timezoneId => $composableBuilder(
    column: $table.timezoneId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  Expression<T> appSettingsRefs<T extends Object>(
    Expression<T> Function($$AppSettingsTableAnnotationComposer a) f,
  ) {
    final $$AppSettingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.appSettings,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppSettingsTableAnnotationComposer(
            $db: $db,
            $table: $db.appSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> goalsRefs<T extends Object>(
    Expression<T> Function($$GoalsTableAnnotationComposer a) f,
  ) {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> todayRecordsRefs<T extends Object>(
    Expression<T> Function($$TodayRecordsTableAnnotationComposer a) f,
  ) {
    final $$TodayRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> journalEntriesRefs<T extends Object>(
    Expression<T> Function($$JournalEntriesTableAnnotationComposer a) f,
  ) {
    final $$JournalEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> healthRecordsRefs<T extends Object>(
    Expression<T> Function($$HealthRecordsTableAnnotationComposer a) f,
  ) {
    final $$HealthRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.healthRecords,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HealthRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.healthRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> aiReportsRefs<T extends Object>(
    Expression<T> Function($$AiReportsTableAnnotationComposer a) f,
  ) {
    final $$AiReportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.aiReports,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AiReportsTableAnnotationComposer(
            $db: $db,
            $table: $db.aiReports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTable,
          UserProfile,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (UserProfile, $$UserProfilesTableReferences),
          UserProfile,
          PrefetchHooks Function({
            bool appSettingsRefs,
            bool goalsRefs,
            bool todayRecordsRefs,
            bool journalEntriesRefs,
            bool healthRecordsRefs,
            bool aiReportsRefs,
          })
        > {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> growthFocus = const Value.absent(),
                Value<String> timezoneId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                deletedAt: deletedAt,
                displayName: displayName,
                growthFocus: growthFocus,
                timezoneId: timezoneId,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> growthFocus = const Value.absent(),
                required String timezoneId,
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                deletedAt: deletedAt,
                displayName: displayName,
                growthFocus: growthFocus,
                timezoneId: timezoneId,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$UserProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                appSettingsRefs = false,
                goalsRefs = false,
                todayRecordsRefs = false,
                journalEntriesRefs = false,
                healthRecordsRefs = false,
                aiReportsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (appSettingsRefs) db.appSettings,
                    if (goalsRefs) db.goals,
                    if (todayRecordsRefs) db.todayRecords,
                    if (journalEntriesRefs) db.journalEntries,
                    if (healthRecordsRefs) db.healthRecords,
                    if (aiReportsRefs) db.aiReports,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (appSettingsRefs)
                        await $_getPrefetchedData<
                          UserProfile,
                          $UserProfilesTable,
                          AppSetting
                        >(
                          currentTable: table,
                          referencedTable: $$UserProfilesTableReferences
                              ._appSettingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UserProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).appSettingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (goalsRefs)
                        await $_getPrefetchedData<
                          UserProfile,
                          $UserProfilesTable,
                          Goal
                        >(
                          currentTable: table,
                          referencedTable: $$UserProfilesTableReferences
                              ._goalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UserProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).goalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (todayRecordsRefs)
                        await $_getPrefetchedData<
                          UserProfile,
                          $UserProfilesTable,
                          TodayRecord
                        >(
                          currentTable: table,
                          referencedTable: $$UserProfilesTableReferences
                              ._todayRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UserProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).todayRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (journalEntriesRefs)
                        await $_getPrefetchedData<
                          UserProfile,
                          $UserProfilesTable,
                          JournalEntry
                        >(
                          currentTable: table,
                          referencedTable: $$UserProfilesTableReferences
                              ._journalEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UserProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).journalEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (healthRecordsRefs)
                        await $_getPrefetchedData<
                          UserProfile,
                          $UserProfilesTable,
                          HealthRecord
                        >(
                          currentTable: table,
                          referencedTable: $$UserProfilesTableReferences
                              ._healthRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UserProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).healthRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (aiReportsRefs)
                        await $_getPrefetchedData<
                          UserProfile,
                          $UserProfilesTable,
                          AiReport
                        >(
                          currentTable: table,
                          referencedTable: $$UserProfilesTableReferences
                              ._aiReportsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UserProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).aiReportsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTable,
      UserProfile,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (UserProfile, $$UserProfilesTableReferences),
      UserProfile,
      PrefetchHooks Function({
        bool appSettingsRefs,
        bool goalsRefs,
        bool todayRecordsRefs,
        bool journalEntriesRefs,
        bool healthRecordsRefs,
        bool aiReportsRefs,
      })
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      required String userId,
      required String localInstallationId,
      Value<String> themeMode,
      Value<String> locale,
      Value<int> firstDayOfWeek,
      Value<bool> onboardingCompleted,
      Value<bool> aiDataSharingEnabled,
      Value<int?> aiDataSharingConsentAt,
      Value<bool> cloudSyncEnabled,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      Value<String> userId,
      Value<String> localInstallationId,
      Value<String> themeMode,
      Value<String> locale,
      Value<int> firstDayOfWeek,
      Value<bool> onboardingCompleted,
      Value<bool> aiDataSharingEnabled,
      Value<int?> aiDataSharingConsentAt,
      Value<bool> cloudSyncEnabled,
      Value<int> rowid,
    });

final class $$AppSettingsTableReferences
    extends BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting> {
  $$AppSettingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UserProfilesTable _userIdTable(_$AppDatabase db) =>
      db.userProfiles.createAlias('app_settings__user_id__user_profiles__id');

  $$UserProfilesTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UserProfilesTableTableManager(
      $_db,
      $_db.userProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localInstallationId => $composableBuilder(
    column: $table.localInstallationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstDayOfWeek => $composableBuilder(
    column: $table.firstDayOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get aiDataSharingEnabled => $composableBuilder(
    column: $table.aiDataSharingEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get aiDataSharingConsentAt => $composableBuilder(
    column: $table.aiDataSharingConsentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cloudSyncEnabled => $composableBuilder(
    column: $table.cloudSyncEnabled,
    builder: (column) => ColumnFilters(column),
  );

  $$UserProfilesTableFilterComposer get userId {
    final $$UserProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableFilterComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localInstallationId => $composableBuilder(
    column: $table.localInstallationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstDayOfWeek => $composableBuilder(
    column: $table.firstDayOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get aiDataSharingEnabled => $composableBuilder(
    column: $table.aiDataSharingEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get aiDataSharingConsentAt => $composableBuilder(
    column: $table.aiDataSharingConsentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cloudSyncEnabled => $composableBuilder(
    column: $table.cloudSyncEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  $$UserProfilesTableOrderingComposer get userId {
    final $$UserProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localInstallationId => $composableBuilder(
    column: $table.localInstallationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<String> get locale =>
      $composableBuilder(column: $table.locale, builder: (column) => column);

  GeneratedColumn<int> get firstDayOfWeek => $composableBuilder(
    column: $table.firstDayOfWeek,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get aiDataSharingEnabled => $composableBuilder(
    column: $table.aiDataSharingEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get aiDataSharingConsentAt => $composableBuilder(
    column: $table.aiDataSharingConsentAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get cloudSyncEnabled => $composableBuilder(
    column: $table.cloudSyncEnabled,
    builder: (column) => column,
  );

  $$UserProfilesTableAnnotationComposer get userId {
    final $$UserProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (AppSetting, $$AppSettingsTableReferences),
          AppSetting,
          PrefetchHooks Function({bool userId})
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> localInstallationId = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> locale = const Value.absent(),
                Value<int> firstDayOfWeek = const Value.absent(),
                Value<bool> onboardingCompleted = const Value.absent(),
                Value<bool> aiDataSharingEnabled = const Value.absent(),
                Value<int?> aiDataSharingConsentAt = const Value.absent(),
                Value<bool> cloudSyncEnabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                userId: userId,
                localInstallationId: localInstallationId,
                themeMode: themeMode,
                locale: locale,
                firstDayOfWeek: firstDayOfWeek,
                onboardingCompleted: onboardingCompleted,
                aiDataSharingEnabled: aiDataSharingEnabled,
                aiDataSharingConsentAt: aiDataSharingConsentAt,
                cloudSyncEnabled: cloudSyncEnabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                required String userId,
                required String localInstallationId,
                Value<String> themeMode = const Value.absent(),
                Value<String> locale = const Value.absent(),
                Value<int> firstDayOfWeek = const Value.absent(),
                Value<bool> onboardingCompleted = const Value.absent(),
                Value<bool> aiDataSharingEnabled = const Value.absent(),
                Value<int?> aiDataSharingConsentAt = const Value.absent(),
                Value<bool> cloudSyncEnabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                userId: userId,
                localInstallationId: localInstallationId,
                themeMode: themeMode,
                locale: locale,
                firstDayOfWeek: firstDayOfWeek,
                onboardingCompleted: onboardingCompleted,
                aiDataSharingEnabled: aiDataSharingEnabled,
                aiDataSharingConsentAt: aiDataSharingConsentAt,
                cloudSyncEnabled: cloudSyncEnabled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AppSettingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$AppSettingsTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$AppSettingsTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (AppSetting, $$AppSettingsTableReferences),
      AppSetting,
      PrefetchHooks Function({bool userId})
    >;
typedef $$GoalsTableCreateCompanionBuilder =
    GoalsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      Value<int?> deletedAt,
      required String userId,
      Value<String?> parentGoalId,
      required String title,
      Value<String?> description,
      required String goalLevel,
      Value<String> status,
      Value<String?> startDate,
      Value<String?> targetDate,
      Value<int?> completedAt,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$GoalsTableUpdateCompanionBuilder =
    GoalsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      Value<int?> deletedAt,
      Value<String> userId,
      Value<String?> parentGoalId,
      Value<String> title,
      Value<String?> description,
      Value<String> goalLevel,
      Value<String> status,
      Value<String?> startDate,
      Value<String?> targetDate,
      Value<int?> completedAt,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$GoalsTableReferences
    extends BaseReferences<_$AppDatabase, $GoalsTable, Goal> {
  $$GoalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UserProfilesTable _userIdTable(_$AppDatabase db) =>
      db.userProfiles.createAlias('goals__user_id__user_profiles__id');

  $$UserProfilesTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UserProfilesTableTableManager(
      $_db,
      $_db.userProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $GoalsTable _parentGoalIdTable(_$AppDatabase db) =>
      db.goals.createAlias('goals__parent_goal_id__goals__id');

  $$GoalsTableProcessedTableManager? get parentGoalId {
    final $_column = $_itemColumn<String>('parent_goal_id');
    if ($_column == null) return null;
    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentGoalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TodayRecordsTable, List<TodayRecord>>
  _priorityOneTodayRecordsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.todayRecords,
        aliasName: 'goals__id__today_records__priority_1_goal_id',
      );

  $$TodayRecordsTableProcessedTableManager get priorityOneTodayRecords {
    final manager = $$TodayRecordsTableTableManager($_db, $_db.todayRecords)
        .filter(
          (f) => f.priority1GoalId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _priorityOneTodayRecordsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TodayRecordsTable, List<TodayRecord>>
  _priorityTwoTodayRecordsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.todayRecords,
        aliasName: 'goals__id__today_records__priority_2_goal_id',
      );

  $$TodayRecordsTableProcessedTableManager get priorityTwoTodayRecords {
    final manager = $$TodayRecordsTableTableManager($_db, $_db.todayRecords)
        .filter(
          (f) => f.priority2GoalId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _priorityTwoTodayRecordsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TodayRecordsTable, List<TodayRecord>>
  _priorityThreeTodayRecordsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.todayRecords,
        aliasName: 'goals__id__today_records__priority_3_goal_id',
      );

  $$TodayRecordsTableProcessedTableManager get priorityThreeTodayRecords {
    final manager = $$TodayRecordsTableTableManager($_db, $_db.todayRecords)
        .filter(
          (f) => f.priority3GoalId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _priorityThreeTodayRecordsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GoalsTableFilterComposer extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goalLevel => $composableBuilder(
    column: $table.goalLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$UserProfilesTableFilterComposer get userId {
    final $$UserProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableFilterComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableFilterComposer get parentGoalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentGoalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> priorityOneTodayRecords(
    Expression<bool> Function($$TodayRecordsTableFilterComposer f) f,
  ) {
    final $$TodayRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.priority1GoalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableFilterComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> priorityTwoTodayRecords(
    Expression<bool> Function($$TodayRecordsTableFilterComposer f) f,
  ) {
    final $$TodayRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.priority2GoalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableFilterComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> priorityThreeTodayRecords(
    Expression<bool> Function($$TodayRecordsTableFilterComposer f) f,
  ) {
    final $$TodayRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.priority3GoalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableFilterComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goalLevel => $composableBuilder(
    column: $table.goalLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$UserProfilesTableOrderingComposer get userId {
    final $$UserProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableOrderingComposer get parentGoalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentGoalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get goalLevel =>
      $composableBuilder(column: $table.goalLevel, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$UserProfilesTableAnnotationComposer get userId {
    final $$UserProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableAnnotationComposer get parentGoalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentGoalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> priorityOneTodayRecords<T extends Object>(
    Expression<T> Function($$TodayRecordsTableAnnotationComposer a) f,
  ) {
    final $$TodayRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.priority1GoalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> priorityTwoTodayRecords<T extends Object>(
    Expression<T> Function($$TodayRecordsTableAnnotationComposer a) f,
  ) {
    final $$TodayRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.priority2GoalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> priorityThreeTodayRecords<T extends Object>(
    Expression<T> Function($$TodayRecordsTableAnnotationComposer a) f,
  ) {
    final $$TodayRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.priority3GoalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GoalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalsTable,
          Goal,
          $$GoalsTableFilterComposer,
          $$GoalsTableOrderingComposer,
          $$GoalsTableAnnotationComposer,
          $$GoalsTableCreateCompanionBuilder,
          $$GoalsTableUpdateCompanionBuilder,
          (Goal, $$GoalsTableReferences),
          Goal,
          PrefetchHooks Function({
            bool userId,
            bool parentGoalId,
            bool priorityOneTodayRecords,
            bool priorityTwoTodayRecords,
            bool priorityThreeTodayRecords,
          })
        > {
  $$GoalsTableTableManager(_$AppDatabase db, $GoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> parentGoalId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> goalLevel = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> startDate = const Value.absent(),
                Value<String?> targetDate = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                deletedAt: deletedAt,
                userId: userId,
                parentGoalId: parentGoalId,
                title: title,
                description: description,
                goalLevel: goalLevel,
                status: status,
                startDate: startDate,
                targetDate: targetDate,
                completedAt: completedAt,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String userId,
                Value<String?> parentGoalId = const Value.absent(),
                required String title,
                Value<String?> description = const Value.absent(),
                required String goalLevel,
                Value<String> status = const Value.absent(),
                Value<String?> startDate = const Value.absent(),
                Value<String?> targetDate = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                deletedAt: deletedAt,
                userId: userId,
                parentGoalId: parentGoalId,
                title: title,
                description: description,
                goalLevel: goalLevel,
                status: status,
                startDate: startDate,
                targetDate: targetDate,
                completedAt: completedAt,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GoalsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                userId = false,
                parentGoalId = false,
                priorityOneTodayRecords = false,
                priorityTwoTodayRecords = false,
                priorityThreeTodayRecords = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (priorityOneTodayRecords) db.todayRecords,
                    if (priorityTwoTodayRecords) db.todayRecords,
                    if (priorityThreeTodayRecords) db.todayRecords,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (userId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.userId,
                                    referencedTable: $$GoalsTableReferences
                                        ._userIdTable(db),
                                    referencedColumn: $$GoalsTableReferences
                                        ._userIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (parentGoalId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentGoalId,
                                    referencedTable: $$GoalsTableReferences
                                        ._parentGoalIdTable(db),
                                    referencedColumn: $$GoalsTableReferences
                                        ._parentGoalIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (priorityOneTodayRecords)
                        await $_getPrefetchedData<
                          Goal,
                          $GoalsTable,
                          TodayRecord
                        >(
                          currentTable: table,
                          referencedTable: $$GoalsTableReferences
                              ._priorityOneTodayRecordsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalsTableReferences(
                                db,
                                table,
                                p0,
                              ).priorityOneTodayRecords,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.priority1GoalId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (priorityTwoTodayRecords)
                        await $_getPrefetchedData<
                          Goal,
                          $GoalsTable,
                          TodayRecord
                        >(
                          currentTable: table,
                          referencedTable: $$GoalsTableReferences
                              ._priorityTwoTodayRecordsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalsTableReferences(
                                db,
                                table,
                                p0,
                              ).priorityTwoTodayRecords,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.priority2GoalId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (priorityThreeTodayRecords)
                        await $_getPrefetchedData<
                          Goal,
                          $GoalsTable,
                          TodayRecord
                        >(
                          currentTable: table,
                          referencedTable: $$GoalsTableReferences
                              ._priorityThreeTodayRecordsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalsTableReferences(
                                db,
                                table,
                                p0,
                              ).priorityThreeTodayRecords,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.priority3GoalId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalsTable,
      Goal,
      $$GoalsTableFilterComposer,
      $$GoalsTableOrderingComposer,
      $$GoalsTableAnnotationComposer,
      $$GoalsTableCreateCompanionBuilder,
      $$GoalsTableUpdateCompanionBuilder,
      (Goal, $$GoalsTableReferences),
      Goal,
      PrefetchHooks Function({
        bool userId,
        bool parentGoalId,
        bool priorityOneTodayRecords,
        bool priorityTwoTodayRecords,
        bool priorityThreeTodayRecords,
      })
    >;
typedef $$TodayRecordsTableCreateCompanionBuilder =
    TodayRecordsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      Value<int?> deletedAt,
      required String userId,
      required String recordDate,
      required int timezoneOffsetMinutes,
      Value<String?> priority1,
      Value<bool> priority1Completed,
      Value<String?> priority1GoalId,
      Value<String?> priority2,
      Value<bool> priority2Completed,
      Value<String?> priority2GoalId,
      Value<String?> priority3,
      Value<bool> priority3Completed,
      Value<String?> priority3GoalId,
      Value<int?> moodScore,
      Value<int?> energyScore,
      Value<int?> researchMinutes,
      Value<int?> learningMinutes,
      Value<String?> dailyNote,
      Value<String> recordStatus,
      Value<int> rowid,
    });
typedef $$TodayRecordsTableUpdateCompanionBuilder =
    TodayRecordsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      Value<int?> deletedAt,
      Value<String> userId,
      Value<String> recordDate,
      Value<int> timezoneOffsetMinutes,
      Value<String?> priority1,
      Value<bool> priority1Completed,
      Value<String?> priority1GoalId,
      Value<String?> priority2,
      Value<bool> priority2Completed,
      Value<String?> priority2GoalId,
      Value<String?> priority3,
      Value<bool> priority3Completed,
      Value<String?> priority3GoalId,
      Value<int?> moodScore,
      Value<int?> energyScore,
      Value<int?> researchMinutes,
      Value<int?> learningMinutes,
      Value<String?> dailyNote,
      Value<String> recordStatus,
      Value<int> rowid,
    });

final class $$TodayRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $TodayRecordsTable, TodayRecord> {
  $$TodayRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UserProfilesTable _userIdTable(_$AppDatabase db) =>
      db.userProfiles.createAlias('today_records__user_id__user_profiles__id');

  $$UserProfilesTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UserProfilesTableTableManager(
      $_db,
      $_db.userProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $GoalsTable _priority1GoalIdTable(_$AppDatabase db) =>
      db.goals.createAlias('today_records__priority_1_goal_id__goals__id');

  $$GoalsTableProcessedTableManager? get priority1GoalId {
    final $_column = $_itemColumn<String>('priority_1_goal_id');
    if ($_column == null) return null;
    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_priority1GoalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $GoalsTable _priority2GoalIdTable(_$AppDatabase db) =>
      db.goals.createAlias('today_records__priority_2_goal_id__goals__id');

  $$GoalsTableProcessedTableManager? get priority2GoalId {
    final $_column = $_itemColumn<String>('priority_2_goal_id');
    if ($_column == null) return null;
    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_priority2GoalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $GoalsTable _priority3GoalIdTable(_$AppDatabase db) =>
      db.goals.createAlias('today_records__priority_3_goal_id__goals__id');

  $$GoalsTableProcessedTableManager? get priority3GoalId {
    final $_column = $_itemColumn<String>('priority_3_goal_id');
    if ($_column == null) return null;
    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_priority3GoalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$JournalEntriesTable, List<JournalEntry>>
  _journalEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.journalEntries,
    aliasName: 'today_records__id__journal_entries__today_record_id',
  );

  $$JournalEntriesTableProcessedTableManager get journalEntriesRefs {
    final manager = $$JournalEntriesTableTableManager(
      $_db,
      $_db.journalEntries,
    ).filter((f) => f.todayRecordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_journalEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$HealthRecordsTable, List<HealthRecord>>
  _healthRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.healthRecords,
    aliasName: 'today_records__id__health_records__today_record_id',
  );

  $$HealthRecordsTableProcessedTableManager get healthRecordsRefs {
    final manager = $$HealthRecordsTableTableManager(
      $_db,
      $_db.healthRecords,
    ).filter((f) => f.todayRecordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_healthRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TodayRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $TodayRecordsTable> {
  $$TodayRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordDate => $composableBuilder(
    column: $table.recordDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timezoneOffsetMinutes => $composableBuilder(
    column: $table.timezoneOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority1 => $composableBuilder(
    column: $table.priority1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get priority1Completed => $composableBuilder(
    column: $table.priority1Completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority2 => $composableBuilder(
    column: $table.priority2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get priority2Completed => $composableBuilder(
    column: $table.priority2Completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority3 => $composableBuilder(
    column: $table.priority3,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get priority3Completed => $composableBuilder(
    column: $table.priority3Completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get moodScore => $composableBuilder(
    column: $table.moodScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get energyScore => $composableBuilder(
    column: $table.energyScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get researchMinutes => $composableBuilder(
    column: $table.researchMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get learningMinutes => $composableBuilder(
    column: $table.learningMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dailyNote => $composableBuilder(
    column: $table.dailyNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordStatus => $composableBuilder(
    column: $table.recordStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$UserProfilesTableFilterComposer get userId {
    final $$UserProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableFilterComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableFilterComposer get priority1GoalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.priority1GoalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableFilterComposer get priority2GoalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.priority2GoalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableFilterComposer get priority3GoalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.priority3GoalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> journalEntriesRefs(
    Expression<bool> Function($$JournalEntriesTableFilterComposer f) f,
  ) {
    final $$JournalEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.todayRecordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableFilterComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> healthRecordsRefs(
    Expression<bool> Function($$HealthRecordsTableFilterComposer f) f,
  ) {
    final $$HealthRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.healthRecords,
      getReferencedColumn: (t) => t.todayRecordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HealthRecordsTableFilterComposer(
            $db: $db,
            $table: $db.healthRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodayRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $TodayRecordsTable> {
  $$TodayRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordDate => $composableBuilder(
    column: $table.recordDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timezoneOffsetMinutes => $composableBuilder(
    column: $table.timezoneOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority1 => $composableBuilder(
    column: $table.priority1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get priority1Completed => $composableBuilder(
    column: $table.priority1Completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority2 => $composableBuilder(
    column: $table.priority2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get priority2Completed => $composableBuilder(
    column: $table.priority2Completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority3 => $composableBuilder(
    column: $table.priority3,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get priority3Completed => $composableBuilder(
    column: $table.priority3Completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get moodScore => $composableBuilder(
    column: $table.moodScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get energyScore => $composableBuilder(
    column: $table.energyScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get researchMinutes => $composableBuilder(
    column: $table.researchMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get learningMinutes => $composableBuilder(
    column: $table.learningMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dailyNote => $composableBuilder(
    column: $table.dailyNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordStatus => $composableBuilder(
    column: $table.recordStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$UserProfilesTableOrderingComposer get userId {
    final $$UserProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableOrderingComposer get priority1GoalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.priority1GoalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableOrderingComposer get priority2GoalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.priority2GoalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableOrderingComposer get priority3GoalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.priority3GoalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TodayRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodayRecordsTable> {
  $$TodayRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get recordDate => $composableBuilder(
    column: $table.recordDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timezoneOffsetMinutes => $composableBuilder(
    column: $table.timezoneOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priority1 =>
      $composableBuilder(column: $table.priority1, builder: (column) => column);

  GeneratedColumn<bool> get priority1Completed => $composableBuilder(
    column: $table.priority1Completed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priority2 =>
      $composableBuilder(column: $table.priority2, builder: (column) => column);

  GeneratedColumn<bool> get priority2Completed => $composableBuilder(
    column: $table.priority2Completed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priority3 =>
      $composableBuilder(column: $table.priority3, builder: (column) => column);

  GeneratedColumn<bool> get priority3Completed => $composableBuilder(
    column: $table.priority3Completed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get moodScore =>
      $composableBuilder(column: $table.moodScore, builder: (column) => column);

  GeneratedColumn<int> get energyScore => $composableBuilder(
    column: $table.energyScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get researchMinutes => $composableBuilder(
    column: $table.researchMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get learningMinutes => $composableBuilder(
    column: $table.learningMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dailyNote =>
      $composableBuilder(column: $table.dailyNote, builder: (column) => column);

  GeneratedColumn<String> get recordStatus => $composableBuilder(
    column: $table.recordStatus,
    builder: (column) => column,
  );

  $$UserProfilesTableAnnotationComposer get userId {
    final $$UserProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableAnnotationComposer get priority1GoalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.priority1GoalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableAnnotationComposer get priority2GoalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.priority2GoalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableAnnotationComposer get priority3GoalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.priority3GoalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> journalEntriesRefs<T extends Object>(
    Expression<T> Function($$JournalEntriesTableAnnotationComposer a) f,
  ) {
    final $$JournalEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.todayRecordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> healthRecordsRefs<T extends Object>(
    Expression<T> Function($$HealthRecordsTableAnnotationComposer a) f,
  ) {
    final $$HealthRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.healthRecords,
      getReferencedColumn: (t) => t.todayRecordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HealthRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.healthRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodayRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodayRecordsTable,
          TodayRecord,
          $$TodayRecordsTableFilterComposer,
          $$TodayRecordsTableOrderingComposer,
          $$TodayRecordsTableAnnotationComposer,
          $$TodayRecordsTableCreateCompanionBuilder,
          $$TodayRecordsTableUpdateCompanionBuilder,
          (TodayRecord, $$TodayRecordsTableReferences),
          TodayRecord,
          PrefetchHooks Function({
            bool userId,
            bool priority1GoalId,
            bool priority2GoalId,
            bool priority3GoalId,
            bool journalEntriesRefs,
            bool healthRecordsRefs,
          })
        > {
  $$TodayRecordsTableTableManager(_$AppDatabase db, $TodayRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodayRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodayRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodayRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> recordDate = const Value.absent(),
                Value<int> timezoneOffsetMinutes = const Value.absent(),
                Value<String?> priority1 = const Value.absent(),
                Value<bool> priority1Completed = const Value.absent(),
                Value<String?> priority1GoalId = const Value.absent(),
                Value<String?> priority2 = const Value.absent(),
                Value<bool> priority2Completed = const Value.absent(),
                Value<String?> priority2GoalId = const Value.absent(),
                Value<String?> priority3 = const Value.absent(),
                Value<bool> priority3Completed = const Value.absent(),
                Value<String?> priority3GoalId = const Value.absent(),
                Value<int?> moodScore = const Value.absent(),
                Value<int?> energyScore = const Value.absent(),
                Value<int?> researchMinutes = const Value.absent(),
                Value<int?> learningMinutes = const Value.absent(),
                Value<String?> dailyNote = const Value.absent(),
                Value<String> recordStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodayRecordsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                deletedAt: deletedAt,
                userId: userId,
                recordDate: recordDate,
                timezoneOffsetMinutes: timezoneOffsetMinutes,
                priority1: priority1,
                priority1Completed: priority1Completed,
                priority1GoalId: priority1GoalId,
                priority2: priority2,
                priority2Completed: priority2Completed,
                priority2GoalId: priority2GoalId,
                priority3: priority3,
                priority3Completed: priority3Completed,
                priority3GoalId: priority3GoalId,
                moodScore: moodScore,
                energyScore: energyScore,
                researchMinutes: researchMinutes,
                learningMinutes: learningMinutes,
                dailyNote: dailyNote,
                recordStatus: recordStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String userId,
                required String recordDate,
                required int timezoneOffsetMinutes,
                Value<String?> priority1 = const Value.absent(),
                Value<bool> priority1Completed = const Value.absent(),
                Value<String?> priority1GoalId = const Value.absent(),
                Value<String?> priority2 = const Value.absent(),
                Value<bool> priority2Completed = const Value.absent(),
                Value<String?> priority2GoalId = const Value.absent(),
                Value<String?> priority3 = const Value.absent(),
                Value<bool> priority3Completed = const Value.absent(),
                Value<String?> priority3GoalId = const Value.absent(),
                Value<int?> moodScore = const Value.absent(),
                Value<int?> energyScore = const Value.absent(),
                Value<int?> researchMinutes = const Value.absent(),
                Value<int?> learningMinutes = const Value.absent(),
                Value<String?> dailyNote = const Value.absent(),
                Value<String> recordStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodayRecordsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                deletedAt: deletedAt,
                userId: userId,
                recordDate: recordDate,
                timezoneOffsetMinutes: timezoneOffsetMinutes,
                priority1: priority1,
                priority1Completed: priority1Completed,
                priority1GoalId: priority1GoalId,
                priority2: priority2,
                priority2Completed: priority2Completed,
                priority2GoalId: priority2GoalId,
                priority3: priority3,
                priority3Completed: priority3Completed,
                priority3GoalId: priority3GoalId,
                moodScore: moodScore,
                energyScore: energyScore,
                researchMinutes: researchMinutes,
                learningMinutes: learningMinutes,
                dailyNote: dailyNote,
                recordStatus: recordStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TodayRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                userId = false,
                priority1GoalId = false,
                priority2GoalId = false,
                priority3GoalId = false,
                journalEntriesRefs = false,
                healthRecordsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (journalEntriesRefs) db.journalEntries,
                    if (healthRecordsRefs) db.healthRecords,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (userId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.userId,
                                    referencedTable:
                                        $$TodayRecordsTableReferences
                                            ._userIdTable(db),
                                    referencedColumn:
                                        $$TodayRecordsTableReferences
                                            ._userIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (priority1GoalId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.priority1GoalId,
                                    referencedTable:
                                        $$TodayRecordsTableReferences
                                            ._priority1GoalIdTable(db),
                                    referencedColumn:
                                        $$TodayRecordsTableReferences
                                            ._priority1GoalIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (priority2GoalId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.priority2GoalId,
                                    referencedTable:
                                        $$TodayRecordsTableReferences
                                            ._priority2GoalIdTable(db),
                                    referencedColumn:
                                        $$TodayRecordsTableReferences
                                            ._priority2GoalIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (priority3GoalId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.priority3GoalId,
                                    referencedTable:
                                        $$TodayRecordsTableReferences
                                            ._priority3GoalIdTable(db),
                                    referencedColumn:
                                        $$TodayRecordsTableReferences
                                            ._priority3GoalIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (journalEntriesRefs)
                        await $_getPrefetchedData<
                          TodayRecord,
                          $TodayRecordsTable,
                          JournalEntry
                        >(
                          currentTable: table,
                          referencedTable: $$TodayRecordsTableReferences
                              ._journalEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TodayRecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).journalEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.todayRecordId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (healthRecordsRefs)
                        await $_getPrefetchedData<
                          TodayRecord,
                          $TodayRecordsTable,
                          HealthRecord
                        >(
                          currentTable: table,
                          referencedTable: $$TodayRecordsTableReferences
                              ._healthRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TodayRecordsTableReferences(
                                db,
                                table,
                                p0,
                              ).healthRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.todayRecordId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TodayRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodayRecordsTable,
      TodayRecord,
      $$TodayRecordsTableFilterComposer,
      $$TodayRecordsTableOrderingComposer,
      $$TodayRecordsTableAnnotationComposer,
      $$TodayRecordsTableCreateCompanionBuilder,
      $$TodayRecordsTableUpdateCompanionBuilder,
      (TodayRecord, $$TodayRecordsTableReferences),
      TodayRecord,
      PrefetchHooks Function({
        bool userId,
        bool priority1GoalId,
        bool priority2GoalId,
        bool priority3GoalId,
        bool journalEntriesRefs,
        bool healthRecordsRefs,
      })
    >;
typedef $$JournalEntriesTableCreateCompanionBuilder =
    JournalEntriesCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      Value<int?> deletedAt,
      required String userId,
      Value<String?> todayRecordId,
      required String entryDate,
      required int timezoneOffsetMinutes,
      Value<String?> mostImportantAccomplishment,
      Value<String?> mostDrainingEvent,
      Value<String?> emotionSource,
      Value<String?> learning,
      Value<String?> tomorrowAdjustment,
      Value<String> entryStatus,
      Value<int> rowid,
    });
typedef $$JournalEntriesTableUpdateCompanionBuilder =
    JournalEntriesCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      Value<int?> deletedAt,
      Value<String> userId,
      Value<String?> todayRecordId,
      Value<String> entryDate,
      Value<int> timezoneOffsetMinutes,
      Value<String?> mostImportantAccomplishment,
      Value<String?> mostDrainingEvent,
      Value<String?> emotionSource,
      Value<String?> learning,
      Value<String?> tomorrowAdjustment,
      Value<String> entryStatus,
      Value<int> rowid,
    });

final class $$JournalEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $JournalEntriesTable, JournalEntry> {
  $$JournalEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $UserProfilesTable _userIdTable(_$AppDatabase db) => db.userProfiles
      .createAlias('journal_entries__user_id__user_profiles__id');

  $$UserProfilesTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UserProfilesTableTableManager(
      $_db,
      $_db.userProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TodayRecordsTable _todayRecordIdTable(_$AppDatabase db) => db
      .todayRecords
      .createAlias('journal_entries__today_record_id__today_records__id');

  $$TodayRecordsTableProcessedTableManager? get todayRecordId {
    final $_column = $_itemColumn<String>('today_record_id');
    if ($_column == null) return null;
    final manager = $$TodayRecordsTableTableManager(
      $_db,
      $_db.todayRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_todayRecordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$JournalEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryDate => $composableBuilder(
    column: $table.entryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timezoneOffsetMinutes => $composableBuilder(
    column: $table.timezoneOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mostImportantAccomplishment => $composableBuilder(
    column: $table.mostImportantAccomplishment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mostDrainingEvent => $composableBuilder(
    column: $table.mostDrainingEvent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emotionSource => $composableBuilder(
    column: $table.emotionSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get learning => $composableBuilder(
    column: $table.learning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tomorrowAdjustment => $composableBuilder(
    column: $table.tomorrowAdjustment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryStatus => $composableBuilder(
    column: $table.entryStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$UserProfilesTableFilterComposer get userId {
    final $$UserProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableFilterComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TodayRecordsTableFilterComposer get todayRecordId {
    final $$TodayRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todayRecordId,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableFilterComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JournalEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryDate => $composableBuilder(
    column: $table.entryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timezoneOffsetMinutes => $composableBuilder(
    column: $table.timezoneOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mostImportantAccomplishment => $composableBuilder(
    column: $table.mostImportantAccomplishment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mostDrainingEvent => $composableBuilder(
    column: $table.mostDrainingEvent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emotionSource => $composableBuilder(
    column: $table.emotionSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get learning => $composableBuilder(
    column: $table.learning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tomorrowAdjustment => $composableBuilder(
    column: $table.tomorrowAdjustment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryStatus => $composableBuilder(
    column: $table.entryStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$UserProfilesTableOrderingComposer get userId {
    final $$UserProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TodayRecordsTableOrderingComposer get todayRecordId {
    final $$TodayRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todayRecordId,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JournalEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get entryDate =>
      $composableBuilder(column: $table.entryDate, builder: (column) => column);

  GeneratedColumn<int> get timezoneOffsetMinutes => $composableBuilder(
    column: $table.timezoneOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mostImportantAccomplishment => $composableBuilder(
    column: $table.mostImportantAccomplishment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mostDrainingEvent => $composableBuilder(
    column: $table.mostDrainingEvent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get emotionSource => $composableBuilder(
    column: $table.emotionSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get learning =>
      $composableBuilder(column: $table.learning, builder: (column) => column);

  GeneratedColumn<String> get tomorrowAdjustment => $composableBuilder(
    column: $table.tomorrowAdjustment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entryStatus => $composableBuilder(
    column: $table.entryStatus,
    builder: (column) => column,
  );

  $$UserProfilesTableAnnotationComposer get userId {
    final $$UserProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TodayRecordsTableAnnotationComposer get todayRecordId {
    final $$TodayRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todayRecordId,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JournalEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JournalEntriesTable,
          JournalEntry,
          $$JournalEntriesTableFilterComposer,
          $$JournalEntriesTableOrderingComposer,
          $$JournalEntriesTableAnnotationComposer,
          $$JournalEntriesTableCreateCompanionBuilder,
          $$JournalEntriesTableUpdateCompanionBuilder,
          (JournalEntry, $$JournalEntriesTableReferences),
          JournalEntry,
          PrefetchHooks Function({bool userId, bool todayRecordId})
        > {
  $$JournalEntriesTableTableManager(
    _$AppDatabase db,
    $JournalEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JournalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JournalEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JournalEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> todayRecordId = const Value.absent(),
                Value<String> entryDate = const Value.absent(),
                Value<int> timezoneOffsetMinutes = const Value.absent(),
                Value<String?> mostImportantAccomplishment =
                    const Value.absent(),
                Value<String?> mostDrainingEvent = const Value.absent(),
                Value<String?> emotionSource = const Value.absent(),
                Value<String?> learning = const Value.absent(),
                Value<String?> tomorrowAdjustment = const Value.absent(),
                Value<String> entryStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                deletedAt: deletedAt,
                userId: userId,
                todayRecordId: todayRecordId,
                entryDate: entryDate,
                timezoneOffsetMinutes: timezoneOffsetMinutes,
                mostImportantAccomplishment: mostImportantAccomplishment,
                mostDrainingEvent: mostDrainingEvent,
                emotionSource: emotionSource,
                learning: learning,
                tomorrowAdjustment: tomorrowAdjustment,
                entryStatus: entryStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String userId,
                Value<String?> todayRecordId = const Value.absent(),
                required String entryDate,
                required int timezoneOffsetMinutes,
                Value<String?> mostImportantAccomplishment =
                    const Value.absent(),
                Value<String?> mostDrainingEvent = const Value.absent(),
                Value<String?> emotionSource = const Value.absent(),
                Value<String?> learning = const Value.absent(),
                Value<String?> tomorrowAdjustment = const Value.absent(),
                Value<String> entryStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                deletedAt: deletedAt,
                userId: userId,
                todayRecordId: todayRecordId,
                entryDate: entryDate,
                timezoneOffsetMinutes: timezoneOffsetMinutes,
                mostImportantAccomplishment: mostImportantAccomplishment,
                mostDrainingEvent: mostDrainingEvent,
                emotionSource: emotionSource,
                learning: learning,
                tomorrowAdjustment: tomorrowAdjustment,
                entryStatus: entryStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$JournalEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false, todayRecordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$JournalEntriesTableReferences
                                    ._userIdTable(db),
                                referencedColumn:
                                    $$JournalEntriesTableReferences
                                        ._userIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (todayRecordId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.todayRecordId,
                                referencedTable: $$JournalEntriesTableReferences
                                    ._todayRecordIdTable(db),
                                referencedColumn:
                                    $$JournalEntriesTableReferences
                                        ._todayRecordIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$JournalEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JournalEntriesTable,
      JournalEntry,
      $$JournalEntriesTableFilterComposer,
      $$JournalEntriesTableOrderingComposer,
      $$JournalEntriesTableAnnotationComposer,
      $$JournalEntriesTableCreateCompanionBuilder,
      $$JournalEntriesTableUpdateCompanionBuilder,
      (JournalEntry, $$JournalEntriesTableReferences),
      JournalEntry,
      PrefetchHooks Function({bool userId, bool todayRecordId})
    >;
typedef $$HealthRecordsTableCreateCompanionBuilder =
    HealthRecordsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      Value<int?> deletedAt,
      required String userId,
      Value<String?> todayRecordId,
      required String recordDate,
      required int timezoneOffsetMinutes,
      Value<int?> sleepDurationMinutes,
      Value<double?> weightKg,
      Value<int?> waterIntakeMl,
      Value<String?> exerciseType,
      Value<int?> exerciseDurationMinutes,
      Value<int?> physicalStateScore,
      Value<String?> note,
      Value<String> dataSource,
      Value<String?> sourceRecordId,
      Value<int> rowid,
    });
typedef $$HealthRecordsTableUpdateCompanionBuilder =
    HealthRecordsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      Value<int?> deletedAt,
      Value<String> userId,
      Value<String?> todayRecordId,
      Value<String> recordDate,
      Value<int> timezoneOffsetMinutes,
      Value<int?> sleepDurationMinutes,
      Value<double?> weightKg,
      Value<int?> waterIntakeMl,
      Value<String?> exerciseType,
      Value<int?> exerciseDurationMinutes,
      Value<int?> physicalStateScore,
      Value<String?> note,
      Value<String> dataSource,
      Value<String?> sourceRecordId,
      Value<int> rowid,
    });

final class $$HealthRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $HealthRecordsTable, HealthRecord> {
  $$HealthRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $UserProfilesTable _userIdTable(_$AppDatabase db) =>
      db.userProfiles.createAlias('health_records__user_id__user_profiles__id');

  $$UserProfilesTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UserProfilesTableTableManager(
      $_db,
      $_db.userProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TodayRecordsTable _todayRecordIdTable(_$AppDatabase db) => db
      .todayRecords
      .createAlias('health_records__today_record_id__today_records__id');

  $$TodayRecordsTableProcessedTableManager? get todayRecordId {
    final $_column = $_itemColumn<String>('today_record_id');
    if ($_column == null) return null;
    final manager = $$TodayRecordsTableTableManager(
      $_db,
      $_db.todayRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_todayRecordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HealthRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $HealthRecordsTable> {
  $$HealthRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordDate => $composableBuilder(
    column: $table.recordDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timezoneOffsetMinutes => $composableBuilder(
    column: $table.timezoneOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sleepDurationMinutes => $composableBuilder(
    column: $table.sleepDurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get waterIntakeMl => $composableBuilder(
    column: $table.waterIntakeMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseType => $composableBuilder(
    column: $table.exerciseType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exerciseDurationMinutes => $composableBuilder(
    column: $table.exerciseDurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get physicalStateScore => $composableBuilder(
    column: $table.physicalStateScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataSource => $composableBuilder(
    column: $table.dataSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRecordId => $composableBuilder(
    column: $table.sourceRecordId,
    builder: (column) => ColumnFilters(column),
  );

  $$UserProfilesTableFilterComposer get userId {
    final $$UserProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableFilterComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TodayRecordsTableFilterComposer get todayRecordId {
    final $$TodayRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todayRecordId,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableFilterComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HealthRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $HealthRecordsTable> {
  $$HealthRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordDate => $composableBuilder(
    column: $table.recordDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timezoneOffsetMinutes => $composableBuilder(
    column: $table.timezoneOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sleepDurationMinutes => $composableBuilder(
    column: $table.sleepDurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get waterIntakeMl => $composableBuilder(
    column: $table.waterIntakeMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseType => $composableBuilder(
    column: $table.exerciseType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exerciseDurationMinutes => $composableBuilder(
    column: $table.exerciseDurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get physicalStateScore => $composableBuilder(
    column: $table.physicalStateScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataSource => $composableBuilder(
    column: $table.dataSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRecordId => $composableBuilder(
    column: $table.sourceRecordId,
    builder: (column) => ColumnOrderings(column),
  );

  $$UserProfilesTableOrderingComposer get userId {
    final $$UserProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TodayRecordsTableOrderingComposer get todayRecordId {
    final $$TodayRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todayRecordId,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HealthRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HealthRecordsTable> {
  $$HealthRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get recordDate => $composableBuilder(
    column: $table.recordDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timezoneOffsetMinutes => $composableBuilder(
    column: $table.timezoneOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sleepDurationMinutes => $composableBuilder(
    column: $table.sleepDurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<int> get waterIntakeMl => $composableBuilder(
    column: $table.waterIntakeMl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exerciseType => $composableBuilder(
    column: $table.exerciseType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get exerciseDurationMinutes => $composableBuilder(
    column: $table.exerciseDurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get physicalStateScore => $composableBuilder(
    column: $table.physicalStateScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get dataSource => $composableBuilder(
    column: $table.dataSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRecordId => $composableBuilder(
    column: $table.sourceRecordId,
    builder: (column) => column,
  );

  $$UserProfilesTableAnnotationComposer get userId {
    final $$UserProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TodayRecordsTableAnnotationComposer get todayRecordId {
    final $$TodayRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todayRecordId,
      referencedTable: $db.todayRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodayRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.todayRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HealthRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HealthRecordsTable,
          HealthRecord,
          $$HealthRecordsTableFilterComposer,
          $$HealthRecordsTableOrderingComposer,
          $$HealthRecordsTableAnnotationComposer,
          $$HealthRecordsTableCreateCompanionBuilder,
          $$HealthRecordsTableUpdateCompanionBuilder,
          (HealthRecord, $$HealthRecordsTableReferences),
          HealthRecord,
          PrefetchHooks Function({bool userId, bool todayRecordId})
        > {
  $$HealthRecordsTableTableManager(_$AppDatabase db, $HealthRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HealthRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HealthRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HealthRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> todayRecordId = const Value.absent(),
                Value<String> recordDate = const Value.absent(),
                Value<int> timezoneOffsetMinutes = const Value.absent(),
                Value<int?> sleepDurationMinutes = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<int?> waterIntakeMl = const Value.absent(),
                Value<String?> exerciseType = const Value.absent(),
                Value<int?> exerciseDurationMinutes = const Value.absent(),
                Value<int?> physicalStateScore = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> dataSource = const Value.absent(),
                Value<String?> sourceRecordId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HealthRecordsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                deletedAt: deletedAt,
                userId: userId,
                todayRecordId: todayRecordId,
                recordDate: recordDate,
                timezoneOffsetMinutes: timezoneOffsetMinutes,
                sleepDurationMinutes: sleepDurationMinutes,
                weightKg: weightKg,
                waterIntakeMl: waterIntakeMl,
                exerciseType: exerciseType,
                exerciseDurationMinutes: exerciseDurationMinutes,
                physicalStateScore: physicalStateScore,
                note: note,
                dataSource: dataSource,
                sourceRecordId: sourceRecordId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String userId,
                Value<String?> todayRecordId = const Value.absent(),
                required String recordDate,
                required int timezoneOffsetMinutes,
                Value<int?> sleepDurationMinutes = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<int?> waterIntakeMl = const Value.absent(),
                Value<String?> exerciseType = const Value.absent(),
                Value<int?> exerciseDurationMinutes = const Value.absent(),
                Value<int?> physicalStateScore = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> dataSource = const Value.absent(),
                Value<String?> sourceRecordId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HealthRecordsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                deletedAt: deletedAt,
                userId: userId,
                todayRecordId: todayRecordId,
                recordDate: recordDate,
                timezoneOffsetMinutes: timezoneOffsetMinutes,
                sleepDurationMinutes: sleepDurationMinutes,
                weightKg: weightKg,
                waterIntakeMl: waterIntakeMl,
                exerciseType: exerciseType,
                exerciseDurationMinutes: exerciseDurationMinutes,
                physicalStateScore: physicalStateScore,
                note: note,
                dataSource: dataSource,
                sourceRecordId: sourceRecordId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HealthRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false, todayRecordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$HealthRecordsTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$HealthRecordsTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (todayRecordId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.todayRecordId,
                                referencedTable: $$HealthRecordsTableReferences
                                    ._todayRecordIdTable(db),
                                referencedColumn: $$HealthRecordsTableReferences
                                    ._todayRecordIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HealthRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HealthRecordsTable,
      HealthRecord,
      $$HealthRecordsTableFilterComposer,
      $$HealthRecordsTableOrderingComposer,
      $$HealthRecordsTableAnnotationComposer,
      $$HealthRecordsTableCreateCompanionBuilder,
      $$HealthRecordsTableUpdateCompanionBuilder,
      (HealthRecord, $$HealthRecordsTableReferences),
      HealthRecord,
      PrefetchHooks Function({bool userId, bool todayRecordId})
    >;
typedef $$AiReportsTableCreateCompanionBuilder =
    AiReportsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      Value<int?> deletedAt,
      required String userId,
      required String reportType,
      required String periodStartDate,
      required String periodEndDate,
      Value<String> inputSourcesJson,
      required String inputHash,
      Value<String?> inputSnapshotJson,
      required String promptVersion,
      Value<String?> provider,
      Value<String?> model,
      Value<String> generationMode,
      Value<String> reportStatus,
      Value<String?> reportContent,
      Value<String?> structuredOutputJson,
      Value<String?> errorCode,
      required int requestedAt,
      Value<int?> generatedAt,
      Value<int> rowid,
    });
typedef $$AiReportsTableUpdateCompanionBuilder =
    AiReportsCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> syncStatus,
      Value<int?> serverVersion,
      Value<int?> lastSyncedAt,
      Value<String?> originDeviceId,
      Value<int?> deletedAt,
      Value<String> userId,
      Value<String> reportType,
      Value<String> periodStartDate,
      Value<String> periodEndDate,
      Value<String> inputSourcesJson,
      Value<String> inputHash,
      Value<String?> inputSnapshotJson,
      Value<String> promptVersion,
      Value<String?> provider,
      Value<String?> model,
      Value<String> generationMode,
      Value<String> reportStatus,
      Value<String?> reportContent,
      Value<String?> structuredOutputJson,
      Value<String?> errorCode,
      Value<int> requestedAt,
      Value<int?> generatedAt,
      Value<int> rowid,
    });

final class $$AiReportsTableReferences
    extends BaseReferences<_$AppDatabase, $AiReportsTable, AiReport> {
  $$AiReportsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UserProfilesTable _userIdTable(_$AppDatabase db) =>
      db.userProfiles.createAlias('ai_reports__user_id__user_profiles__id');

  $$UserProfilesTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UserProfilesTableTableManager(
      $_db,
      $_db.userProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AiReportsTableFilterComposer
    extends Composer<_$AppDatabase, $AiReportsTable> {
  $$AiReportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reportType => $composableBuilder(
    column: $table.reportType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodStartDate => $composableBuilder(
    column: $table.periodStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodEndDate => $composableBuilder(
    column: $table.periodEndDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputSourcesJson => $composableBuilder(
    column: $table.inputSourcesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputHash => $composableBuilder(
    column: $table.inputHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputSnapshotJson => $composableBuilder(
    column: $table.inputSnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promptVersion => $composableBuilder(
    column: $table.promptVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generationMode => $composableBuilder(
    column: $table.generationMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reportStatus => $composableBuilder(
    column: $table.reportStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reportContent => $composableBuilder(
    column: $table.reportContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get structuredOutputJson => $composableBuilder(
    column: $table.structuredOutputJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$UserProfilesTableFilterComposer get userId {
    final $$UserProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableFilterComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiReportsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiReportsTable> {
  $$AiReportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportType => $composableBuilder(
    column: $table.reportType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodStartDate => $composableBuilder(
    column: $table.periodStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodEndDate => $composableBuilder(
    column: $table.periodEndDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputSourcesJson => $composableBuilder(
    column: $table.inputSourcesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputHash => $composableBuilder(
    column: $table.inputHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputSnapshotJson => $composableBuilder(
    column: $table.inputSnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promptVersion => $composableBuilder(
    column: $table.promptVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generationMode => $composableBuilder(
    column: $table.generationMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportStatus => $composableBuilder(
    column: $table.reportStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportContent => $composableBuilder(
    column: $table.reportContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get structuredOutputJson => $composableBuilder(
    column: $table.structuredOutputJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$UserProfilesTableOrderingComposer get userId {
    final $$UserProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiReportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiReportsTable> {
  $$AiReportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get reportType => $composableBuilder(
    column: $table.reportType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get periodStartDate => $composableBuilder(
    column: $table.periodStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get periodEndDate => $composableBuilder(
    column: $table.periodEndDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inputSourcesJson => $composableBuilder(
    column: $table.inputSourcesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inputHash =>
      $composableBuilder(column: $table.inputHash, builder: (column) => column);

  GeneratedColumn<String> get inputSnapshotJson => $composableBuilder(
    column: $table.inputSnapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get promptVersion => $composableBuilder(
    column: $table.promptVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get generationMode => $composableBuilder(
    column: $table.generationMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reportStatus => $composableBuilder(
    column: $table.reportStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reportContent => $composableBuilder(
    column: $table.reportContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get structuredOutputJson => $composableBuilder(
    column: $table.structuredOutputJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<int> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );

  $$UserProfilesTableAnnotationComposer get userId {
    final $$UserProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AiReportsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiReportsTable,
          AiReport,
          $$AiReportsTableFilterComposer,
          $$AiReportsTableOrderingComposer,
          $$AiReportsTableAnnotationComposer,
          $$AiReportsTableCreateCompanionBuilder,
          $$AiReportsTableUpdateCompanionBuilder,
          (AiReport, $$AiReportsTableReferences),
          AiReport,
          PrefetchHooks Function({bool userId})
        > {
  $$AiReportsTableTableManager(_$AppDatabase db, $AiReportsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiReportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiReportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> reportType = const Value.absent(),
                Value<String> periodStartDate = const Value.absent(),
                Value<String> periodEndDate = const Value.absent(),
                Value<String> inputSourcesJson = const Value.absent(),
                Value<String> inputHash = const Value.absent(),
                Value<String?> inputSnapshotJson = const Value.absent(),
                Value<String> promptVersion = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String> generationMode = const Value.absent(),
                Value<String> reportStatus = const Value.absent(),
                Value<String?> reportContent = const Value.absent(),
                Value<String?> structuredOutputJson = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<int> requestedAt = const Value.absent(),
                Value<int?> generatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiReportsCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                deletedAt: deletedAt,
                userId: userId,
                reportType: reportType,
                periodStartDate: periodStartDate,
                periodEndDate: periodEndDate,
                inputSourcesJson: inputSourcesJson,
                inputHash: inputHash,
                inputSnapshotJson: inputSnapshotJson,
                promptVersion: promptVersion,
                provider: provider,
                model: model,
                generationMode: generationMode,
                reportStatus: reportStatus,
                reportContent: reportContent,
                structuredOutputJson: structuredOutputJson,
                errorCode: errorCode,
                requestedAt: requestedAt,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<int?> lastSyncedAt = const Value.absent(),
                Value<String?> originDeviceId = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                required String userId,
                required String reportType,
                required String periodStartDate,
                required String periodEndDate,
                Value<String> inputSourcesJson = const Value.absent(),
                required String inputHash,
                Value<String?> inputSnapshotJson = const Value.absent(),
                required String promptVersion,
                Value<String?> provider = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String> generationMode = const Value.absent(),
                Value<String> reportStatus = const Value.absent(),
                Value<String?> reportContent = const Value.absent(),
                Value<String?> structuredOutputJson = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                required int requestedAt,
                Value<int?> generatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiReportsCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                serverVersion: serverVersion,
                lastSyncedAt: lastSyncedAt,
                originDeviceId: originDeviceId,
                deletedAt: deletedAt,
                userId: userId,
                reportType: reportType,
                periodStartDate: periodStartDate,
                periodEndDate: periodEndDate,
                inputSourcesJson: inputSourcesJson,
                inputHash: inputHash,
                inputSnapshotJson: inputSnapshotJson,
                promptVersion: promptVersion,
                provider: provider,
                model: model,
                generationMode: generationMode,
                reportStatus: reportStatus,
                reportContent: reportContent,
                structuredOutputJson: structuredOutputJson,
                errorCode: errorCode,
                requestedAt: requestedAt,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AiReportsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$AiReportsTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$AiReportsTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AiReportsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiReportsTable,
      AiReport,
      $$AiReportsTableFilterComposer,
      $$AiReportsTableOrderingComposer,
      $$AiReportsTableAnnotationComposer,
      $$AiReportsTableCreateCompanionBuilder,
      $$AiReportsTableUpdateCompanionBuilder,
      (AiReport, $$AiReportsTableReferences),
      AiReport,
      PrefetchHooks Function({bool userId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db, _db.goals);
  $$TodayRecordsTableTableManager get todayRecords =>
      $$TodayRecordsTableTableManager(_db, _db.todayRecords);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(_db, _db.journalEntries);
  $$HealthRecordsTableTableManager get healthRecords =>
      $$HealthRecordsTableTableManager(_db, _db.healthRecords);
  $$AiReportsTableTableManager get aiReports =>
      $$AiReportsTableTableManager(_db, _db.aiReports);
}
