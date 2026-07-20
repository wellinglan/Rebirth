import 'package:flutter/material.dart';

Future<bool> showAiJournalScopeDialog(
  BuildContext context, {
  bool isDaily = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('aiJournalScopeDialog'),
          title: const Text('将 Journal 加入本次预览？'),
          content: SingleChildScrollView(
            child: Text(
              isDaily
                  ? '这会读取该日期已保存的五项 Journal 回答，其中可能包含私人信息。'
                        '这些内容只用于本次请求，不会成为永久默认选择。'
                        '预览会先在本机显示，最终发送仍需再次确认。'
                  : '这会读取最近 7 天有内容的 Journal 结构化回答，其中可能包含私人情绪、关系和个人经历。'
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
