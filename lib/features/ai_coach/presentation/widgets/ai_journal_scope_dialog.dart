import 'package:flutter/material.dart';

Future<bool> showAiJournalScopeDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('aiJournalScopeDialog'),
          title: const Text('将 Journal 加入本次预览？'),
          content: const SingleChildScrollView(
            child: Text(
              '这会读取最近 7 天有内容的 Journal 结构化回答，其中可能包含私人情绪、关系和个人经历。'
              '当前只在本机生成预览，不会发送网络；未来真正生成报告时仍需你再次主动操作。'
              '关闭 Journal 范围后，这些内容不会进入输入 Bundle。本次预览也不会自动保存输入快照。',
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('cancelAiJournalScopeButton'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('confirmAiJournalScopeButton'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('将 Journal 加入本次预览'),
            ),
          ],
        ),
      ) ??
      false;
}
