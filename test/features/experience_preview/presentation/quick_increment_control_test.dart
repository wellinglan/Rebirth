import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/experience_preview/presentation/experience_preview_page.dart';
import 'package:rebirth/features/experience_preview/presentation/widgets/quick_increment_control.dart';

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('null and zero both increase by the selected step', (
    tester,
  ) async {
    final values = <int?>[];
    await _pumpControl(tester, initialValue: null, values: values);

    await tester.tap(find.byKey(const ValueKey('饮水量Increase')));
    await tester.pump();
    expect(values.last, 250);

    await _pumpControl(tester, initialValue: 0, values: values);
    await tester.tap(find.byKey(const ValueKey('饮水量Increase')));
    await tester.pump();
    expect(values.last, 250);
  });

  testWidgets('increment and decrement preserve exact arithmetic', (
    tester,
  ) async {
    final values = <int?>[];
    await _pumpControl(tester, initialValue: 750, values: values);

    await tester.tap(find.byKey(const ValueKey('饮水量Increase')));
    await tester.pump();
    expect(values.last, 1000);

    await tester.tap(find.byKey(const ValueKey('饮水量Decrease')));
    await tester.pump();
    expect(values.last, 750);
  });

  testWidgets('decrement clamps to zero and leaves null unchanged', (
    tester,
  ) async {
    final values = <int?>[];
    await _pumpControl(tester, initialValue: 100, values: values);
    await tester.tap(find.byKey(const ValueKey('饮水量Decrease')));
    await tester.pump();
    expect(values.last, 0);

    values.clear();
    await _pumpControl(tester, initialValue: null, values: values);
    await tester.tap(find.byKey(const ValueKey('饮水量Decrease')));
    await tester.pump();
    expect(values, isEmpty);
    expect(find.text('未记录'), findsOneWidget);
  });

  testWidgets('changing step does not change value and next add uses it', (
    tester,
  ) async {
    final values = <int?>[];
    await _pumpControl(tester, initialValue: 250, values: values, width: 400);

    await tester.tap(find.byKey(const ValueKey('饮水量StepSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('饮水量Step500')));
    await tester.pumpAndSettle();

    expect(values, isEmpty);
    final increase = find.byKey(const ValueKey('饮水量Increase'));
    expect(
      find.descendant(of: increase, matching: find.text('+500 ml')),
      findsOneWidget,
    );

    await tester.tap(increase);
    await tester.pump();
    expect(values.last, 750);
  });

  testWidgets('rapid taps are accumulated without losing an event', (
    tester,
  ) async {
    final values = <int?>[];
    await _pumpControl(tester, initialValue: null, values: values);

    final increase = find.byKey(const ValueKey('饮水量Increase'));
    await tester.tap(increase);
    await tester.tap(increase);
    await tester.pump();

    expect(values, [250, 500]);
    expect(find.text('500 ml'), findsWidgets);
  });

  testWidgets('clear restores null while zero remains an explicit value', (
    tester,
  ) async {
    final values = <int?>[];
    await _pumpControl(tester, initialValue: 0, values: values);
    expect(find.text('0 ml'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('饮水量Clear')));
    await tester.pump();
    expect(values.last, isNull);
    expect(find.text('未记录'), findsOneWidget);
  });

  testWidgets('keyboard Enter and Space trigger the focused add button', (
    tester,
  ) async {
    final values = <int?>[];
    await _pumpControl(tester, initialValue: 0, values: values);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(values, [250, 500]);
  });

  testWidgets('semantics exposes current value, step and unit', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpControl(tester, initialValue: 750, values: <int?>[]);

    expect(find.bySemanticsLabel(RegExp(r'当前饮水量.*750 ml')), findsOneWidget);
    expect(find.bySemanticsLabel('增加 250 ml'), findsOneWidget);
    expect(find.bySemanticsLabel('选择饮水量步长，当前 250 ml'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('320px with TextScaler 2 has no overflow', (tester) async {
    await _pumpControl(
      tester,
      initialValue: 750,
      values: <int?>[],
      width: 320,
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });

  test('duration values split into readable hours and minutes', () {
    expect(formatDurationMinutes(null), '未记录');
    expect(formatDurationMinutes(0), '0 分钟');
    expect(formatDurationMinutes(30), '30 分钟');
    expect(formatDurationMinutes(60), '1 小时');
    expect(formatDurationMinutes(90), '1 小时 30 分钟');
  });
}

Future<void> _pumpControl(
  WidgetTester tester, {
  required int? initialValue,
  required List<int?> values,
  double width = 600,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var value = initialValue;
  var step = 250;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => QuickIncrementControl(
              value: value,
              stepOptions: const [100, 250, 500],
              selectedStep: step,
              unit: 'ml',
              minimumValue: 0,
              label: '饮水量',
              onChanged: (next) {
                values.add(next);
                setState(() => value = next);
              },
              onStepChanged: (next) => setState(() => step = next),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
