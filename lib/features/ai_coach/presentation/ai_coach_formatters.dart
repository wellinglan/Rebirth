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
      'gateway_disabled' => '服务器未启用 AI 生成',
      'authentication_required' => '需要重新登录',
      'provider_authentication_failed' => '服务器无法认证 AI Provider',
      'provider_rate_limited' => 'AI Provider 请求受限',
      'provider_timeout' => '生成请求超时',
      'provider_refused' => 'AI Provider 拒绝生成',
      'input_hash_mismatch' => '输入完整性校验失败',
      'unsupported_report_type' => '报告类型不受支持',
      'unsupported_prompt_version' => 'Prompt Version 不受支持',
      'unsupported_scope' => '数据范围不受支持',
      'invalid_request' || 'invalid_input' => '生成请求无效',
      'request_failed' => '请求未能完成',
      'response_invalid' => '返回内容无法读取',
      'outcome_unknown' => '无法确定是否已产生结果或费用，系统不会自动重试',
      'result_expired' => '服务器临时结果已过期',
      'server_state_not_found' => '服务器未找到请求状态',
      'request_binding_failed' => '恢复信息保存失败，生成请求未发送',
      'network_outcome_unknown' => '网络中断，结果待确认',
      'cancelled' => '请求已取消',
      'unknown' || null => '生成未完成',
      _ => '生成未完成',
    };
  }
}
