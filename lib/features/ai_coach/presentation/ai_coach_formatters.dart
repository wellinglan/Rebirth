import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

abstract final class AiCoachFormatters {
  static String shortHash(String hash) {
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 8)}…${hash.substring(hash.length - 8)}';
  }

  static String reportType(AiReportType type) {
    return switch (type) {
      AiReportType.dailyInsight => '每日洞察',
      AiReportType.weeklyReport => '每周回顾',
      AiReportType.monthlyReflection => '月度复盘',
      AiReportType.tomorrowSuggestion => '明日建议',
      AiReportType.trendExplanation => '趋势解释',
    };
  }

  static String reportStatus(AiReportStatus status) {
    return switch (status) {
      AiReportStatus.pending => '待处理',
      AiReportStatus.completed => '已完成',
      AiReportStatus.failed => '生成失败',
    };
  }

  static String recordStatus(String status) {
    return switch (status) {
      'completed' => '已完成',
      'draft' => '草稿',
      _ => '未知状态',
    };
  }

  static String minutes(int? value) {
    if (value == null) return '未记录';
    final hours = value ~/ 60;
    final minutes = value % 60;
    if (hours == 0) return '$minutes 分钟';
    if (minutes == 0) return '$hours 小时';
    return '$hours 小时 $minutes 分钟';
  }

  static String averageMinutes(double? value) {
    if (value == null) return '未记录';
    if (value == value.roundToDouble()) return minutes(value.round());
    return '${value.toStringAsFixed(1)} 分钟';
  }

  static String score(num? value) {
    if (value == null) return '未记录';
    return value is int || value == value.roundToDouble()
        ? '${value.round()} / 5'
        : '${value.toStringAsFixed(1)} / 5';
  }

  static String timestamp(int? milliseconds) {
    if (milliseconds == null) return '未记录';
    final value = DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
      isUtc: true,
    ).toLocal();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  static String nullableText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? '未填写' : trimmed;
  }

  static String failureCode(String? code) {
    return switch (code) {
      'provider_unavailable' => '生成服务暂不可用',
      'request_failed' => '请求未能完成',
      'response_invalid' => '返回内容无法读取',
      'cancelled' => '请求已取消',
      'unknown' || null => '生成未完成',
      _ => '生成未完成',
    };
  }
}
