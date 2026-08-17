import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/experience_preview/presentation/experience_preview_page.dart';

void main() {
  const fixedNow = DateTimeService(now: _fixedNow);

  testWidgets('home uses the injected clock and stable local quote', (
    tester,
  ) async {
    await _pumpPage(tester, service: fixedNow);

    expect(find.text('2026年8月17日 · 星期一'), findsOneWidget);
    expect(find.text('10:08'), findsOneWidget);
    expect(find.text(experienceQuoteFor(_fixedNow())), findsOneWidget);
    expect(find.byKey(const ValueKey('homeDayAsset')), findsOneWidget);
    expect(find.text('本地固定寄语 · 不调用 AI'), findsOneWidget);
  });

  testWidgets('night clock selects the bundled night asset', (tester) async {
    await _pumpPage(
      tester,
      service: DateTimeService(now: () => DateTime(2026, 8, 17, 22, 15)),
    );
    expect(find.byKey(const ValueKey('homeNightAsset')), findsOneWidget);
  });

  testWidgets('health water increment updates exact text and cup together', (
    tester,
  ) async {
    await _pumpPage(tester, service: fixedNow);
    await _selectView(tester, '健康');

    expect(find.text('未记录'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('饮水量Increase')));
    await tester.pump();

    expect(find.text('250 ml'), findsWidgets);
    expect(find.byKey(const ValueKey('waterLevel250')), findsOneWidget);
  });

  testWidgets('today prototype simulates save without persistence', (
    tester,
  ) async {
    await _pumpPage(tester, service: fixedNow);
    await _selectView(tester, '今日');
    await tester.drag(
      find.byKey(const ValueKey('experiencePreviewScrollView')),
      const Offset(0, -1600),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('prototypeTodaySave')));
    await tester.pump();

    expect(find.text('原型数据未写入本地记录'), findsOneWidget);
  });

  testWidgets('today uses wellbeing fields and keeps scores across views', (
    tester,
  ) async {
    await _pumpPage(tester, service: fixedNow, width: 1200);
    await _selectView(tester, '今日');

    expect(find.byKey(const ValueKey('prototypeMoodRating')), findsOneWidget);
    expect(find.byKey(const ValueKey('prototypeEnergyRating')), findsOneWidget);
    expect(find.byKey(const ValueKey('心情Icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('精力Icon')), findsOneWidget);

    tester.widget<Slider>(find.byKey(const ValueKey('心情Slider'))).onChanged!(7);
    await tester.enterText(
      find.byKey(const ValueKey('心情Description')),
      '今天比较轻松',
    );
    await tester.pump();
    await _selectView(tester, '健康');
    await _selectView(tester, '今日');

    expect(find.text('7 / 10'), findsOneWidget);
    expect(find.text('今天比较轻松'), findsOneWidget);
  });

  testWidgets('reset clears prototype wellbeing scores and descriptions', (
    tester,
  ) async {
    await _pumpPage(tester, service: fixedNow, width: 720);
    await _selectView(tester, '今日');
    tester.widget<Slider>(find.byKey(const ValueKey('心情Slider'))).onChanged!(6);
    await tester.enterText(
      find.byKey(const ValueKey('心情Description')),
      '需要休息一下',
    );
    await tester.pump();

    tester
        .widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.restart_alt),
        )
        .onPressed!();
    await tester.pump();

    expect(find.text('6 / 10'), findsNothing);
    expect(find.text('需要休息一下'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('心情ScoreText'))).data,
      '未记录',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('精力ScoreText'))).data,
      '未记录',
    );
  });

  testWidgets('health uses one wellbeing field without the old controls', (
    tester,
  ) async {
    await _pumpPage(tester, service: fixedNow);
    await _selectView(tester, '健康');

    expect(
      find.byKey(const ValueKey('prototypePhysicalStateRating')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('prototypePhysicalState')), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('recording sections expose restrained identifying icons', (
    tester,
  ) async {
    await _pumpPage(tester, service: fixedNow);
    await _selectView(tester, '今日');
    expect(find.byKey(const ValueKey('研究Icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('学习Icon')), findsOneWidget);

    await _selectView(tester, '健康');
    expect(find.byKey(const ValueKey('饮水Icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('运动Icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('睡眠Icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('身体感受Icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('体重Icon')), findsOneWidget);
  });

  testWidgets('exact duration input preserves invalid text and converts 90', (
    tester,
  ) async {
    await _pumpPage(tester, service: fixedNow);
    await _selectView(tester, '今日');
    final field = find.byKey(const ValueKey('研究精确分钟Field'));

    await tester.enterText(field, '90');
    await tester.pump();
    expect(find.text('1 小时 30 分钟'), findsOneWidget);

    await tester.enterText(field, '-1');
    await tester.pump();
    expect(find.text('请输入非负整数'), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);
  });

  testWidgets('duration presets are hidden until requested and can fill 90', (
    tester,
  ) async {
    await _pumpPage(tester, service: fixedNow, width: 720);
    await _selectView(tester, '今日');
    expect(find.byType(ActionChip), findsNothing);

    final field = find.byKey(const ValueKey('研究精确分钟Field'));
    await tester.enterText(field, '77');
    final presetButton = find.byKey(const ValueKey('研究时间预设Button'));
    await tester.ensureVisible(presetButton);
    await tester.pumpAndSettle();
    await tester.tap(presetButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('研究时间预设BottomSheet')), findsOneWidget);

    Navigator.of(
      tester.element(find.byKey(const ValueKey('研究时间预设BottomSheet'))),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.text('77'), findsOneWidget);

    await tester.ensureVisible(presetButton);
    await tester.pumpAndSettle();
    await tester.tap(presetButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 小时 30 分钟'));
    await tester.pumpAndSettle();
    expect(find.text('1 小时 30 分钟'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 412.0, 720.0, 1200.0]) {
    testWidgets('home preview has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await _pumpPage(tester, service: fixedNow, width: width);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('today and health have no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await _pumpPage(tester, service: fixedNow, width: width);
      await _selectView(tester, '今日');
      expect(tester.takeException(), isNull);
      await _selectView(tester, '健康');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('320px and TextScaler 2 can scroll all three views', (
    tester,
  ) async {
    await _pumpPage(tester, service: fixedNow, width: 320, textScale: 2);
    expect(tester.takeException(), isNull);

    await _selectView(tester, '健康');
    await tester.drag(
      find.byKey(const ValueKey('experiencePreviewScrollView')),
      const Offset(0, -700),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await _selectView(tester, '今日');
    expect(tester.takeException(), isNull);
  });

  test('preview presentation does not import persistence or sync layers', () {
    final files = Directory(
      'lib/features/experience_preview/presentation',
    ).listSync(recursive: true).whereType<File>();
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final forbidden in const [
        'package:drift',
        'AppDatabase',
        'Repository',
        'SyncCoordinator',
        'ApiClient',
        'DateTime.now()',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: file.path);
      }
    }
  });
}

Future<void> _selectView(WidgetTester tester, String label) async {
  final dropdown = find.byKey(const ValueKey('experiencePreviewDropdown'));
  if (dropdown.evaluate().isNotEmpty) {
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
  } else {
    await tester.tap(find.text(label).first);
  }
  await tester.pumpAndSettle();
}

DateTime _fixedNow() => DateTime(2026, 8, 17, 10, 8);

Future<void> _pumpPage(
  WidgetTester tester, {
  required DateTimeService service,
  double width = 720,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1100);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dateTimeServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const ExperiencePreviewPage(),
        ),
      ),
    ),
  );
  await tester.pump();
}
