import 'dart:collection';
import 'dart:convert';

enum AiReportHelpfulness {
  helpful('helpful'),
  notHelpful('not_helpful');

  const AiReportHelpfulness(this.databaseValue);
  final String databaseValue;

  static AiReportHelpfulness fromDatabaseValue(String value) =>
      values.firstWhere(
        (item) => item.databaseValue == value,
        orElse: () => throw const FormatException('Invalid helpfulness.'),
      );
}

enum AiReportFeedbackReason {
  repetitive('repetitive', '内容重复'),
  notFactuallyGrounded('not_factually_grounded', '与记录事实不符'),
  notActionable('not_actionable', '建议不够可执行'),
  tooGeneric('too_generic', '内容过于笼统'),
  missedImportantContext('missed_important_context', '遗漏重要背景'),
  toneNotHelpful('tone_not_helpful', '表达方式没有帮助'),
  hardToUnderstand('hard_to_understand', '内容难以理解');

  const AiReportFeedbackReason(this.code, this.label);
  final String code;
  final String label;

  static AiReportFeedbackReason fromCode(String value) => values.firstWhere(
    (item) => item.code == value,
    orElse: () => throw const FormatException('Invalid feedback reason.'),
  );
}

final class AiReportFeedbackReasonCodec {
  const AiReportFeedbackReasonCodec();

  String encode(Iterable<AiReportFeedbackReason> reasons) {
    final codes = reasons.map((item) => item.code).toSet().toList()..sort();
    return jsonEncode(codes);
  }

  List<AiReportFeedbackReason> decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! List || decoded.any((item) => item is! String)) {
      throw const FormatException('Invalid feedback reasons JSON.');
    }
    final codes = decoded.cast<String>();
    if (codes.toSet().length != codes.length) {
      throw const FormatException('Duplicate feedback reason.');
    }
    final sorted = [...codes]..sort();
    if (!_same(codes, sorted)) {
      throw const FormatException('Feedback reasons are not canonical.');
    }
    return List.unmodifiable(sorted.map(AiReportFeedbackReason.fromCode));
  }

  bool _same(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

enum AiReportFeedbackSyncStatus {
  localOnly('local_only'),
  pendingPush('pending_push'),
  synced('synced'),
  conflict('conflict'),
  pendingDelete('pending_delete');

  const AiReportFeedbackSyncStatus(this.databaseValue);
  final String databaseValue;

  static AiReportFeedbackSyncStatus fromDatabaseValue(String value) =>
      values.firstWhere(
        (item) => item.databaseValue == value,
        orElse: () => throw const FormatException('Invalid feedback status.'),
      );
}

final class AiReportFeedback {
  AiReportFeedback({
    required this.id,
    required this.userId,
    required this.reportId,
    required this.reportVersion,
    required this.reportType,
    required this.helpfulness,
    required Iterable<AiReportFeedbackReason> reasons,
    required this.promptId,
    required this.promptVersion,
    required this.syncStatus,
    required this.serverVersion,
    required this.lastSyncedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    this.remoteSnapshot,
  }) : reasons = UnmodifiableListView(reasons) {
    if (id.trim().isEmpty ||
        userId.trim().isEmpty ||
        reportId.trim().isEmpty ||
        reportVersion < 1 ||
        reportType.trim().isEmpty ||
        promptId.trim().isEmpty ||
        promptVersion.trim().isEmpty ||
        updatedAt < createdAt ||
        (helpfulness == AiReportHelpfulness.helpful && reasons.isNotEmpty) ||
        (helpfulness == AiReportHelpfulness.notHelpful && reasons.isEmpty)) {
      throw ArgumentError('Invalid AI report feedback.');
    }
  }

  final String id;
  final String userId;
  final String reportId;
  final int reportVersion;
  final String reportType;
  final AiReportHelpfulness helpfulness;
  final List<AiReportFeedbackReason> reasons;
  final String promptId;
  final String promptVersion;
  final AiReportFeedbackSyncStatus syncStatus;
  final int? serverVersion;
  final int? lastSyncedAt;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final AiReportFeedbackRemoteSnapshot? remoteSnapshot;

  bool get isCleared => deletedAt != null;
}

final class AiReportFeedbackRemoteSnapshot {
  AiReportFeedbackRemoteSnapshot({
    required this.id,
    required this.helpfulness,
    required Iterable<AiReportFeedbackReason> reasons,
    required this.serverVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  }) : reasons = UnmodifiableListView(reasons);

  final String id;
  final AiReportHelpfulness helpfulness;
  final List<AiReportFeedbackReason> reasons;
  final int serverVersion;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
}
