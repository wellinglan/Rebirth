const _localDailyQuotes = <String>[
  '慢一点，也是在认真前进。',
  '给今天留一点呼吸的空间。',
  '先照顾好当下，再走向更远的地方。',
  '把注意力放回真正重要的事情。',
  '允许今天有自己的节奏。',
  '小小的行动，也会留下清晰的方向。',
  '认真生活，不必每一刻都用力。',
];

String localDailyQuote(String localDate) {
  var hash = 0;
  for (final unit in localDate.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _localDailyQuotes[hash % _localDailyQuotes.length];
}
