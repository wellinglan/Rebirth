final class SystemJournalPromptSpec {
  const SystemJournalPromptSpec({
    required this.stableKey,
    required this.questionText,
    required this.displayOrder,
    this.helperText,
  });

  final String stableKey;
  final String questionText;
  final String? helperText;
  final int displayOrder;
}

abstract final class JournalPromptLimits {
  static const enabledPromptCount = 20;
  static const totalPromptCount = 100;
  static const questionTextLength = 500;
  static const helperTextLength = 500;
  static const answerTextLength = 20000;
}

abstract final class JournalPromptCatalog {
  static const accomplishmentKey = 'system.accomplishment';
  static const drainingEventKey = 'system.draining_event';
  static const emotionSourceKey = 'system.emotion_source';
  static const learningKey = 'system.learning';
  static const tomorrowAdjustmentKey = 'system.tomorrow_adjustment';

  static const prompts = <SystemJournalPromptSpec>[
    SystemJournalPromptSpec(
      stableKey: accomplishmentKey,
      questionText: '今天最重要的完成是什么？',
      displayOrder: 0,
    ),
    SystemJournalPromptSpec(
      stableKey: drainingEventKey,
      questionText: '今天最消耗我的事情是什么？',
      displayOrder: 1,
    ),
    SystemJournalPromptSpec(
      stableKey: emotionSourceKey,
      questionText: '今天主要情绪的来源是什么？',
      displayOrder: 2,
    ),
    SystemJournalPromptSpec(
      stableKey: learningKey,
      questionText: '今天我学到了什么？',
      displayOrder: 3,
    ),
    SystemJournalPromptSpec(
      stableKey: tomorrowAdjustmentKey,
      questionText: '明天我想如何调整？',
      displayOrder: 4,
    ),
  ];
}
