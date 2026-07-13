import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/today/presentation/widgets/duration_input_field.dart';

void main() {
  final initialValueCases = <({int? initial, String hours, String minutes})>[
    (initial: null, hours: '', minutes: ''),
    (initial: 0, hours: '0', minutes: '0'),
    (initial: 30, hours: '0', minutes: '30'),
    (initial: 60, hours: '1', minutes: '0'),
    (initial: 90, hours: '1', minutes: '30'),
    (initial: 420, hours: '7', minutes: '0'),
  ];

  for (final testCase in initialValueCases) {
    testWidgets('splits initial ${testCase.initial} minutes', (tester) async {
      await _pumpField(tester, initialMinutes: testCase.initial);

      expect(_fieldText(tester, 0), testCase.hours);
      expect(_fieldText(tester, 1), testCase.minutes);
    });
  }

  final conversionCases = <({String hours, String minutes, int? expected})>[
    (hours: '', minutes: '', expected: null),
    (hours: '', minutes: '30', expected: 30),
    (hours: '1', minutes: '', expected: 60),
    (hours: '1', minutes: '30', expected: 90),
    (hours: '0', minutes: '0', expected: 0),
  ];

  for (final testCase in conversionCases) {
    testWidgets(
      'converts ${testCase.hours}:${testCase.minutes} to ${testCase.expected}',
      (tester) async {
        int? output = 999;
        await _pumpField(
          tester,
          initialMinutes: 60,
          onChanged: (value) => output = value,
        );

        await tester.enterText(_field(tester, 0), testCase.hours);
        await tester.enterText(_field(tester, 1), testCase.minutes);

        expect(output, testCase.expected);
      },
    );
  }

  final invalidHourCases = <String>['-1', '1.5', 'abc'];
  for (final input in invalidHourCases) {
    testWidgets('rejects invalid hour $input', (tester) async {
      final formKey = GlobalKey<FormState>();
      await _pumpField(tester, formKey: formKey);

      await tester.enterText(_field(tester, 0), input);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();

      expect(find.text('请输入非负整数'), findsOneWidget);
    });
  }

  final invalidMinuteCases = <String>['-1', '1.5', 'abc'];
  for (final input in invalidMinuteCases) {
    testWidgets('rejects invalid minute $input', (tester) async {
      final formKey = GlobalKey<FormState>();
      await _pumpField(tester, formKey: formKey);

      await tester.enterText(_field(tester, 1), input);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();

      expect(find.text('请输入 0–59 的整数'), findsOneWidget);
    });
  }

  testWidgets('rejects minute 60', (tester) async {
    final formKey = GlobalKey<FormState>();
    await _pumpField(tester, formKey: formKey);

    await tester.enterText(_field(tester, 1), '60');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();

    expect(find.text('分钟需小于 60'), findsOneWidget);
  });

  testWidgets('1 hour 30 minute chip outputs 90', (tester) async {
    int? output;
    await _pumpField(
      tester,
      onChanged: (value) => output = value,
      quickValues: const <int>[90, 450],
    );

    await tester.tap(find.text('1小时30分钟'));
    await tester.pump();

    expect(output, 90);
    expect(_fieldText(tester, 0), '1');
    expect(_fieldText(tester, 1), '30');
  });

  testWidgets('7 hour 30 minute chip outputs 450', (tester) async {
    int? output;
    await _pumpField(
      tester,
      onChanged: (value) => output = value,
      quickValues: const <int>[90, 450],
    );

    await tester.tap(find.text('7小时30分钟'));
    await tester.pump();

    expect(output, 450);
    expect(_fieldText(tester, 0), '7');
    expect(_fieldText(tester, 1), '30');
  });
}

Future<void> _pumpField(
  WidgetTester tester, {
  int? initialMinutes,
  ValueChanged<int?>? onChanged,
  List<int> quickValues = const <int>[],
  GlobalKey<FormState>? formKey,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: SizedBox(
            width: 500,
            child: DurationInputField(
              label: '测试时间',
              initialMinutes: initialMinutes,
              quickValues: quickValues,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

Finder _field(WidgetTester tester, int index) {
  return find.byType(TextFormField).at(index);
}

String _fieldText(WidgetTester tester, int index) {
  return tester.widget<TextFormField>(_field(tester, index)).controller!.text;
}
