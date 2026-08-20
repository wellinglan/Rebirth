import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/shared/widgets/compact_duration_editor.dart';
import 'package:rebirth/shared/widgets/compact_quantity_editor.dart';
import 'package:rebirth/shared/widgets/metric_description_field.dart';

void main() {
  group('CompactDurationEditor', () {
    testWidgets('splits null, zero, and total minutes predictably', (
      tester,
    ) async {
      await _pumpDuration(tester, initialValue: null);
      expect(_text(tester, '测试时长HoursField'), isEmpty);
      expect(_text(tester, '测试时长MinutesField'), isEmpty);

      await _pumpDuration(tester, initialValue: 0);
      expect(_text(tester, '测试时长HoursField'), '0');
      expect(_text(tester, '测试时长MinutesField'), '0');

      await _pumpDuration(tester, initialValue: 90);
      expect(_text(tester, '测试时长HoursField'), '1');
      expect(_text(tester, '测试时长MinutesField'), '30');
    });

    testWidgets('direct input preserves null and explicit zero semantics', (
      tester,
    ) async {
      final values = <int?>[];
      await _pumpDuration(tester, onChanged: values.add);

      await tester.enterText(find.byKey(const ValueKey('测试时长HoursField')), '0');
      await tester.enterText(
        find.byKey(const ValueKey('测试时长MinutesField')),
        '0',
      );
      expect(values.last, 0);

      await tester.enterText(find.byKey(const ValueKey('测试时长HoursField')), '');
      await tester.enterText(
        find.byKey(const ValueKey('测试时长MinutesField')),
        '',
      );
      expect(values.last, isNull);
    });

    testWidgets('direct hours and minutes convert to total minutes', (
      tester,
    ) async {
      final values = <int?>[];
      await _pumpDuration(tester, onChanged: values.add);

      await tester.enterText(find.byKey(const ValueKey('测试时长HoursField')), '1');
      await tester.enterText(
        find.byKey(const ValueKey('测试时长MinutesField')),
        '30',
      );
      await tester.pump();

      expect(values.last, 90);
      expect(find.text('1 小时 30 分钟'), findsOneWidget);
    });

    testWidgets('invalid hours and minutes fail form validation', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await _pumpDuration(tester, formKey: formKey);

      await tester.enterText(
        find.byKey(const ValueKey('测试时长HoursField')),
        '-1',
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('请输入非负整数'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('测试时长HoursField')), '1');
      await tester.enterText(
        find.byKey(const ValueKey('测试时长MinutesField')),
        '60',
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('分钟需小于 60'), findsOneWidget);
    });

    testWidgets('custom additions accumulate without losing updates', (
      tester,
    ) async {
      final values = <int?>[];
      await _pumpDuration(tester, onChanged: values.add);

      await _addDuration(tester, minutes: '15');
      await _addDuration(tester, minutes: '15');

      expect(values, [15, 30]);
      expect(find.text('30 分钟'), findsOneWidget);
    });

    testWidgets('clear and one-level undo restore the previous value', (
      tester,
    ) async {
      final values = <int?>[];
      await _pumpDuration(tester, initialValue: 90, onChanged: values.add);

      await tester.tap(find.byKey(const ValueKey('测试时长Clear')));
      await tester.pump();
      expect(values.last, isNull);
      await tester.tap(find.byKey(const ValueKey('测试时长Undo')));
      await tester.pump();
      expect(values.last, 90);
      expect(
        tester
            .widget<IconButton>(
              find.descendant(
                of: find.byKey(const ValueKey('测试时长Undo')),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('is responsive at 320px with TextScaler 2', (tester) async {
      await _pumpDuration(tester, width: 320, textScale: 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics names value and actions', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpDuration(tester, initialValue: 30);

      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('测试时长DurationSemantics')))
            .label,
        contains('当前30 分钟'),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('测试时长Add'))).label,
        contains('增加测试时长'),
      );
      semantics.dispose();
    });

    for (final entry in <String, LogicalKeyboardKey>{
      'Enter': LogicalKeyboardKey.enter,
      'Space': LogicalKeyboardKey.space,
    }.entries) {
      testWidgets('${entry.key} activates the focused add action', (
        tester,
      ) async {
        await _pumpDuration(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(entry.value);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('测试时长AddDialog')), findsOneWidget);
      });
    }
  });

  group('CompactQuantityEditor', () {
    testWidgets('null plus a custom amount starts from zero', (tester) async {
      final values = <num?>[];
      await _pumpQuantity(tester, onChanged: values.add);

      await tester.tap(find.byKey(const ValueKey('饮水Add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('饮水AddValueField')),
        '250',
      );
      await tester.tap(find.byKey(const ValueKey('饮水ConfirmAdd')));
      await tester.pumpAndSettle();

      expect(values.last, 250);
      expect(find.text('250 ml'), findsOneWidget);
    });

    testWidgets('direct zero, clear, and undo remain distinct', (tester) async {
      final values = <num?>[];
      await _pumpQuantity(tester, onChanged: values.add);

      await tester.enterText(find.byKey(const ValueKey('饮水ValueField')), '0');
      await tester.pump();
      expect(values.last, 0);
      await tester.tap(find.byKey(const ValueKey('饮水Clear')));
      await tester.pump();
      expect(values.last, isNull);
      await tester.tap(find.byKey(const ValueKey('饮水Undo')));
      await tester.pump();
      expect(values.last, 0);
    });

    testWidgets('negative integer does not emit and fails validation', (
      tester,
    ) async {
      final values = <num?>[];
      final formKey = GlobalKey<FormState>();
      await _pumpQuantity(tester, formKey: formKey, onChanged: values.add);

      await tester.enterText(find.byKey(const ValueKey('饮水ValueField')), '-1');
      expect(values, isEmpty);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('请输入非负整数'), findsOneWidget);
    });

    testWidgets('is responsive at 320px with TextScaler 2', (tester) async {
      await _pumpQuantity(tester, width: 320, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('MetricDescriptionField', () {
    testWidgets('starts collapsed, expands, and clears to empty', (
      tester,
    ) async {
      final values = <String>[];
      await _pumpDescription(tester, onChanged: values.add);

      expect(find.byKey(const ValueKey('科研时间Description')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('科研时间DescriptionAdd')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('科研时间Description')),
        '专注完成实验',
      );
      expect(values.last, '专注完成实验');

      await tester.tap(find.byKey(const ValueKey('科研时间DescriptionClear')));
      await tester.pump();
      expect(values.last, isEmpty);
      expect(find.byKey(const ValueKey('科研时间Description')), findsNothing);
    });

    testWidgets('more than 80 characters fails form validation', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await _pumpDescription(tester, formKey: formKey);
      await tester.tap(find.byKey(const ValueKey('科研时间DescriptionAdd')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('科研时间Description')),
        'x' * 81,
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('最多输入 80 个字符'), findsOneWidget);
    });

    testWidgets('expanded field is responsive at 320px with TextScaler 2', (
      tester,
    ) async {
      await _pumpDescription(tester, width: 320, textScale: 2);
      await tester.tap(find.byKey(const ValueKey('科研时间DescriptionAdd')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpDuration(
  WidgetTester tester, {
  int? initialValue,
  ValueChanged<int?>? onChanged,
  GlobalKey<FormState>? formKey,
  double width = 500,
  double textScale = 1,
}) async {
  await _pump(
    tester,
    width: width,
    textScale: textScale,
    formKey: formKey,
    child: CompactDurationEditor(
      label: '测试时长',
      icon: Icons.timer_outlined,
      value: initialValue,
      onChanged: onChanged ?? (_) {},
    ),
  );
}

Future<void> _pumpQuantity(
  WidgetTester tester, {
  ValueChanged<num?>? onChanged,
  GlobalKey<FormState>? formKey,
  double width = 500,
  double textScale = 1,
}) async {
  await _pump(
    tester,
    formKey: formKey,
    width: width,
    textScale: textScale,
    child: CompactQuantityEditor(
      label: '饮水',
      icon: Icons.water_drop_outlined,
      value: null,
      unit: 'ml',
      onChanged: onChanged ?? (_) {},
    ),
  );
}

Future<void> _pumpDescription(
  WidgetTester tester, {
  ValueChanged<String>? onChanged,
  GlobalKey<FormState>? formKey,
  double width = 500,
  double textScale = 1,
}) async {
  await _pump(
    tester,
    formKey: formKey,
    width: width,
    textScale: textScale,
    child: MetricDescriptionField(
      label: '科研时间',
      value: '',
      hintText: '一句话记下科研投入或进展',
      onChanged: onChanged ?? (_) {},
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  GlobalKey<FormState>? formKey,
  double width = 500,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Form(key: formKey, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _addDuration(
  WidgetTester tester, {
  String hours = '',
  String minutes = '',
}) async {
  await tester.tap(find.byKey(const ValueKey('测试时长Add')));
  await tester.pumpAndSettle();
  if (hours.isNotEmpty) {
    await tester.enterText(
      find.byKey(const ValueKey('测试时长AddHoursField')),
      hours,
    );
  }
  if (minutes.isNotEmpty) {
    await tester.enterText(
      find.byKey(const ValueKey('测试时长AddMinutesField')),
      minutes,
    );
  }
  await tester.tap(find.byKey(const ValueKey('测试时长ConfirmAdd')));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
}
