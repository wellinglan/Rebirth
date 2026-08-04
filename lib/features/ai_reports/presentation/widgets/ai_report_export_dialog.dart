import 'package:flutter/material.dart';

Future<bool> showAiReportExportDialog(
  BuildContext context, {
  required bool exportAll,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('aiReportExportConfirmationDialog'),
          scrollable: true,
          title: Text(exportAll ? '导出全部 AI 报告' : '导出这份 AI 报告'),
          content: Text(
            exportAll
                ? '导出文件将包含当前账号全部未删除报告的正文和版本历史，可能含有敏感个人信息。请只保存到你信任的位置。'
                : '导出文件将包含这份报告的正文和版本历史，可能含有敏感个人信息。请只保存到你信任的位置。',
          ),
          actions: [
            TextButton(
              key: const ValueKey('cancelAiReportExportButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              key: const ValueKey('confirmAiReportExportButton'),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.save_alt),
              label: const Text('选择保存位置'),
            ),
          ],
        ),
      ) ??
      false;
}
