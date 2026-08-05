import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/personal_data_backup.dart';

class PersonalDataBackupEncoder {
  const PersonalDataBackupEncoder();

  PersonalDataBackupDocument createDocument({
    required String exportedAt,
    required String appVersion,
    required int databaseSchemaVersion,
    required List<PersonalDataModuleSnapshot> modules,
  }) {
    final draft = PersonalDataBackupDocument(
      exportedAt: exportedAt,
      appVersion: appVersion,
      databaseSchemaVersion: databaseSchemaVersion,
      modules: modules,
      payloadSha256: '',
    );
    return draft.copyWith(
      payloadSha256: calculatePayloadSha256(draft.dataJson()),
    );
  }

  String calculatePayloadSha256(Map<String, Object?> data) {
    final canonical = jsonEncode(_canonicalize(data));
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  bool verify(PersonalDataBackupDocument document) {
    return document.payloadSha256.isNotEmpty &&
        document.payloadSha256 == calculatePayloadSha256(document.dataJson());
  }

  String encode(PersonalDataBackupDocument document) {
    if (!verify(document)) {
      throw const FormatException('Personal data backup integrity mismatch.');
    }
    return const JsonEncoder.withIndent(
      ' ',
    ).convert(_canonicalize(document.toJson()));
  }

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          throw const FormatException('Backup JSON keys must be strings.');
        }
        sorted[key] = _canonicalize(entry.value);
      }
      return sorted;
    }
    if (value is Iterable) {
      return value.map(_canonicalize).toList(growable: false);
    }
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    throw const FormatException('Backup contains an unsupported JSON value.');
  }
}
