import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/plan/presentation/widgets/plan_date_parts_field.dart';

void main() {
  testWidgets('main build uses lightweight year month day controls', (
    tester,
  ) async {
    await _pumpField(tester, value: '2026-07-14');

    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(_partHasText('testDateYear', '2026'), findsOneWidget);
    expect(_partHasText('testDateMonth', '7'), findsOneWidget);
    expect(_partHasText('testDateDay', '14'), findsOneWidget);
  });

  testWidgets('single tap opens a lazy picker and selects a month', (
    tester,
  ) async {
    String? output;
    await _pumpField(
      tester,
      value: '2026-07-14',
      onChanged: (value) => output = value,
    );

    await _openPicker(tester, 'Month');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('testDateMonthPicker')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('testDateMonthOption8')));
    await tester.pumpAndSettle();

    expect(output, '2026-08-14');
  });

  testWidgets('selecting year month and day emits YYYY-MM-DD', (tester) async {
    String? output;
    await _pumpField(tester, value: null, onChanged: (value) => output = value);

    await _selectPart(tester, 'Year', 2023);
    await _selectPart(tester, 'Month', 3);
    await _selectPart(tester, 'Day', 3);

    expect(output, '2023-03-03');
  });

  testWidgets('changing month clamps day to the final valid date', (
    tester,
  ) async {
    String? output;
    await _pumpField(
      tester,
      value: '2026-01-31',
      onChanged: (value) => output = value,
    );

    await _selectPart(tester, 'Month', 2);

    expect(output, '2026-02-28');
    expect(_partHasText('testDateDay', '28'), findsOneWidget);
  });

  testWidgets('changing leap year clamps February 29', (tester) async {
    String? output;
    await _pumpField(
      tester,
      value: '2028-02-29',
      onChanged: (value) => output = value,
    );

    await _selectPart(tester, 'Year', 2029);

    expect(output, '2029-02-28');
  });

  testWidgets('double-clicking each part supports manual input', (
    tester,
  ) async {
    String? output;
    await _pumpField(
      tester,
      value: '2026-07-14',
      onChanged: (value) => output = value,
    );

    await _enterManualPart(tester, 'Year', '2027');
    await _enterManualPart(tester, 'Month', '8');
    await _enterManualPart(tester, 'Day', '15');

    expect(output, '2027-08-15');
  });

  testWidgets('invalid manual month shows the specified error', (tester) async {
    await _pumpField(tester, value: '2026-07-14');
    _openManual(tester, 'Month');
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('testDateManualMonth')),
      '13',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('请输入 1-12 的月份'), findsOneWidget);
    expect(find.byKey(const ValueKey('testDateManualMonth')), findsOneWidget);
  });

  testWidgets('disabled state cannot open picker or manual mode', (
    tester,
  ) async {
    await _pumpField(tester, value: '2026-07-14', enabled: false);

    for (final part in ['Year', 'Month', 'Day']) {
      final gesture = tester.widget<GestureDetector>(
        find.byKey(ValueKey('testDate$part')),
      );
      expect(gesture.onTap, isNull);
      expect(gesture.onDoubleTap, isNull);
    }
  });

  testWidgets('required empty date shows the specified error', (tester) async {
    await _pumpField(tester, value: null, isRequired: true);

    await tester.tap(find.byKey(const ValueKey('validateDate')));
    await tester.pump();

    expect(find.text('请选择日期'), findsOneWidget);
  });
}

Future<void> _pumpField(
  WidgetTester tester, {
  required String? value,
  ValueChanged<String?>? onChanged,
  bool enabled = true,
  bool isRequired = false,
}) async {
  final formKey = GlobalKey<FormState>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: Column(
            children: [
              PlanDatePartsField(
                fieldId: 'testDate',
                label: '测试日期',
                value: value,
                enabled: enabled,
                isRequired: isRequired,
                yearStart: 2020,
                yearEnd: 2030,
                onChanged: onChanged ?? (_) {},
              ),
              FilledButton(
                key: const ValueKey('validateDate'),
                onPressed: () => formKey.currentState!.validate(),
                child: const Text('校验'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _partHasText(String key, String text) {
  return find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.text(text),
  );
}

Future<void> _selectPart(WidgetTester tester, String part, int value) async {
  await _openPicker(tester, part);
  await tester.pumpAndSettle();
  final option = find.byKey(ValueKey('testDate${part}Option$value'));
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

Future<void> _enterManualPart(
  WidgetTester tester,
  String part,
  String value,
) async {
  _openManual(tester, part);
  await tester.pump();
  await tester.enterText(find.byKey(ValueKey('testDateManual$part')), value);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void _openManual(WidgetTester tester, String part) {
  tester
      .widget<GestureDetector>(find.byKey(ValueKey('testDate$part')))
      .onDoubleTap!();
}

Future<void> _openPicker(WidgetTester tester, String part) async {
  await tester.tap(find.byKey(ValueKey('testDate$part')));
  await tester.pump(const Duration(milliseconds: 400));
}
