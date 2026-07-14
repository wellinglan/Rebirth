import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/plan/presentation/widgets/plan_date_parts_field.dart';

void main() {
  testWidgets('displays separate year, month, and day controls', (
    tester,
  ) async {
    await _pumpField(tester, value: '2026-07-14');

    expect(find.text('年'), findsOneWidget);
    expect(find.text('月'), findsOneWidget);
    expect(find.text('日'), findsOneWidget);
    expect(_selectedValue(tester, 'testDateYear'), 2026);
    expect(_selectedValue(tester, 'testDateMonth'), 7);
    expect(_selectedValue(tester, 'testDateDay'), 14);
  });

  testWidgets('changing month emits YYYY-MM-DD and clamps the day', (
    tester,
  ) async {
    String? output;
    await _pumpField(
      tester,
      value: '2026-01-31',
      onChanged: (value) => output = value,
    );

    _changeDropdown(tester, 'testDateMonth', 2);
    await tester.pump();

    expect(output, '2026-02-28');
    expect(_selectedValue(tester, 'testDateDay'), 28);
  });

  testWidgets('changing leap year clamps February 29 to February 28', (
    tester,
  ) async {
    String? output;
    await _pumpField(
      tester,
      value: '2028-02-29',
      onChanged: (value) => output = value,
    );

    _changeDropdown(tester, 'testDateYear', 2029);
    await tester.pump();

    expect(output, '2029-02-28');
    expect(_selectedValue(tester, 'testDateDay'), 28);
  });

  testWidgets('double-clicking each part supports valid manual input', (
    tester,
  ) async {
    String? output;
    await _pumpField(
      tester,
      value: '2026-07-14',
      onChanged: (value) => output = value,
    );

    await _enterManualPart(
      tester,
      'testDateYear',
      'testDateManualYear',
      '2027',
    );
    await _enterManualPart(tester, 'testDateMonth', 'testDateManualMonth', '8');
    await _enterManualPart(tester, 'testDateDay', 'testDateManualDay', '15');

    expect(output, '2027-08-15');
  });

  testWidgets('invalid manual month shows the specified error', (tester) async {
    await _pumpField(tester, value: '2026-07-14');

    await _doubleTap(tester, find.byKey(const ValueKey('testDateMonth')));
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

  testWidgets('disabled state cannot edit dropdowns or enter manual mode', (
    tester,
  ) async {
    await _pumpField(tester, value: '2026-07-14', enabled: false);

    for (final part in ['Year', 'Month', 'Day']) {
      final finder = find.descendant(
        of: find.byKey(ValueKey('testDate$part')),
        matching: find.byType(DropdownButtonFormField<int>),
      );
      expect(
        tester.widget<DropdownButtonFormField<int>>(finder).onChanged,
        isNull,
      );
      expect(
        tester
            .widget<GestureDetector>(find.byKey(ValueKey('testDate$part')))
            .onDoubleTap,
        isNull,
      );
      expect(find.byKey(ValueKey('testDateManual$part')), findsNothing);
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

int? _selectedValue(WidgetTester tester, String fieldKey) {
  final finder = find.descendant(
    of: find.byKey(ValueKey(fieldKey)),
    matching: find.byType(DropdownButtonFormField<int>),
  );
  return tester.widget<DropdownButtonFormField<int>>(finder).initialValue;
}

void _changeDropdown(WidgetTester tester, String fieldKey, int value) {
  final finder = find.descendant(
    of: find.byKey(ValueKey(fieldKey)),
    matching: find.byType(DropdownButtonFormField<int>),
  );
  tester.widget<DropdownButtonFormField<int>>(finder).onChanged!(value);
}

Future<void> _enterManualPart(
  WidgetTester tester,
  String partKey,
  String manualKey,
  String value,
) async {
  await _doubleTap(tester, find.byKey(ValueKey(partKey)));
  await tester.pump();
  await tester.enterText(find.byKey(ValueKey(manualKey)), value);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  tester.widget<GestureDetector>(finder).onDoubleTap!();
  await tester.pump();
}
