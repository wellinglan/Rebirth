import 'package:flutter/material.dart';

Future<bool> showAiReportDeleteDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('aiReportDeleteDialog'),
          title: const Text('删除本地报告？'),
          content: const SingleChildScrollView(
            child: Text(
              '这只会软删除当前本地 AIReport，不会删除 Today、Journal、Health、Plan 或 Growth 数据，'
              '也不会改变 AI 数据授权。当前无法撤销，除非未来增加回收站。',
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('cancelAiReportDeleteButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('confirmAiReportDeleteButton'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除本地报告'),
            ),
          ],
        ),
      ) ??
      false;
}
