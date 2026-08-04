import 'package:flutter/material.dart';

Future<bool> showAiReportArchiveDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('aiReportArchiveDialog'),
          title: const Text('归档 AI 报告'),
          content: const SingleChildScrollView(
            child: Text(
              '归档不会删除报告正文或版本历史，也不会重新生成报告或调用 AI。'
              '归档状态可在你主动同步 AI 报告时同步到其他设备。',
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('cancelAiReportArchiveButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('confirmAiReportArchiveButton'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('归档报告'),
            ),
          ],
        ),
      ) ??
      false;
}
