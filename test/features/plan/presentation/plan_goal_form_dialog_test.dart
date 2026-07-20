import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';
import 'package:rebirth/features/plan/presentation/widgets/plan_date_parts_field.dart';
import 'package:rebirth/features/plan/presentation/widgets/plan_goal_form_dialog.dart';

void main() {
  testWidgets(
    'new goal defaults to today, month, and one natural month target',
    (tester) async {
      await _pumpDialog(tester);

      expect(_dateField(tester, 'planGoalStartDateField').value, '2026-07-14');
      expect(_dateField(tester, 'planGoalTargetDateField').value, '2026-08-14');
      expect(_selectedLevel(tester), PlanGoalLevel.month);
      expect(_dateField(tester, 'planGoalTargetDateField').enabled, isFalse);
      expect(find.text('优先级'), findsOneWidget);
      expect(find.text('排序'), findsNothing);
      expect(find.text('数值越小越靠前'), findsOneWidget);
      expect(find.byKey(const ValueKey('planGoalStatusField')), findsNothing);
    },
  );

  testWidgets('changing start date recalculates a non-custom target', (
    tester,
  ) async {
    await _pumpDialog(tester);

    _dateField(tester, 'planGoalStartDateField').onChanged('2026-03-31');
    await tester.pump();

    expect(_dateField(tester, 'planGoalStartDateField').value, '2026-03-31');
    expect(_dateField(tester, 'planGoalTargetDateField').value, '2026-04-30');
  });

  testWidgets('changing level to quarter recalculates target by three months', (
    tester,
  ) async {
    await _pumpDialog(tester);
    _dateField(tester, 'planGoalStartDateField').onChanged('2026-03-31');
    await tester.pump();

    _changeLevel(tester, PlanGoalLevel.quarter);
    await tester.pump();

    expect(_dateField(tester, 'planGoalTargetDateField').value, '2026-06-30');
    expect(_dateField(tester, 'planGoalTargetDateField').enabled, isFalse);
  });

  testWidgets('custom level enables optional target and submits null', (
    tester,
  ) async {
    PlanGoalSaveData? submitted;
    await _pumpDialog(tester, onSubmit: (data) async => submitted = data);
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '自定义周期',
    );

    _changeLevel(tester, PlanGoalLevel.custom);
    await tester.pump();
    expect(_dateField(tester, 'planGoalTargetDateField').enabled, isTrue);
    _dateField(tester, 'planGoalTargetDateField').onChanged(null);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('submitPlanGoalButton')));
    await tester.pumpAndSettle();

    expect(submitted?.goalLevel, PlanGoalLevel.custom);
    expect(submitted?.targetDate, isNull);
    expect(submitted?.status, PlanGoalStatus.notStarted);
  });

  testWidgets('custom target before start date reports an error', (
    tester,
  ) async {
    var submitCount = 0;
    await _pumpDialog(tester, onSubmit: (_) async => submitCount++);
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '日期范围',
    );
    _changeLevel(tester, PlanGoalLevel.custom);
    await tester.pump();
    _dateField(tester, 'planGoalTargetDateField').onChanged('2026-07-13');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('submitPlanGoalButton')));
    await tester.pump();

    expect(find.text('目标日期不能早于开始日期'), findsOneWidget);
    expect(submitCount, 0);
  });

  testWidgets('negative priority prevents submission', (tester) async {
    var submitCount = 0;
    await _pumpDialog(tester, onSubmit: (_) async => submitCount++);
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '优先级校验',
    );
    await tester.enterText(
      find.byKey(const ValueKey('planGoalPriorityField')),
      '-1',
    );

    await tester.tap(find.byKey(const ValueKey('submitPlanGoalButton')));
    await tester.pump();

    expect(find.text('请输入非负整数'), findsOneWidget);
    expect(submitCount, 0);
  });

  testWidgets('save failure keeps dialog and entered values', (tester) async {
    await _pumpDialog(
      tester,
      onSubmit: (_) async => throw StateError('save failed'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '不会丢失的标题',
    );

    await tester.tap(find.byKey(const ValueKey('submitPlanGoalButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planGoalFormDialog')), findsOneWidget);
    expect(find.text('不会丢失的标题'), findsOneWidget);
    expect(find.text('创建失败，请重试'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('submitPlanGoalButton')),
          )
          .onPressed,
      isNotNull,
    );
  });

  for (final testCase in <(double, bool)>[
    (320, true),
    (360, true),
    (412, true),
    (720, false),
    (1200, false),
  ]) {
    testWidgets(
      '${testCase.$1}px dialog uses the expected responsive date layout',
      (tester) async {
        await _pumpDialog(tester, size: Size(testCase.$1, 1400));

        for (final fieldId in ['planStartDate', 'planTargetDate']) {
          expect(
            find.byKey(
              ValueKey(
                '$fieldId${testCase.$2 ? 'StackedLayout' : 'InlineLayout'}',
              ),
            ),
            findsOneWidget,
          );
          final yearText = tester.widget<Text>(
            find.descendant(
              of: find.byKey(ValueKey('${fieldId}Year')),
              matching: find.text('2026'),
            ),
          );
          expect(yearText.maxLines, 1);
          expect(yearText.softWrap, isFalse);
        }

        final startRect = tester.getRect(
          find.byKey(const ValueKey('planGoalStartDateField')),
        );
        final targetRect = tester.getRect(
          find.byKey(const ValueKey('planGoalTargetDateField')),
        );
        expect(startRect.bottom, lessThan(targetRect.top));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final textScale in [1.0, 1.3, 1.5, 2.0]) {
    testWidgets('$textScale text scale keeps the date dialog overflow-free', (
      tester,
    ) async {
      await _pumpDialog(
        tester,
        size: const Size(720, 1600),
        textScaleFactor: textScale,
      );

      final layoutSuffix = textScale > 1.3 ? 'StackedLayout' : 'InlineLayout';
      expect(
        find.byKey(ValueKey('planStartDate$layoutSuffix')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('planTargetDate$layoutSuffix')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  Future<void> Function(PlanGoalSaveData data)? onSubmit,
  Size size = const Size(1000, 1200),
  double textScaleFactor = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
        child: child!,
      ),
      home: Scaffold(
        body: PlanGoalFormDialog(
          existingGoal: null,
          parentGoalId: null,
          defaultStartDate: '2026-07-14',
          defaultGoalLevel: PlanGoalLevel.month,
          onSubmit: onSubmit ?? (_) async {},
        ),
      ),
    ),
  );
  await tester.pump();
}

PlanDatePartsField _dateField(WidgetTester tester, String key) {
  return tester.widget<PlanDatePartsField>(find.byKey(ValueKey(key)));
}

PlanGoalLevel? _selectedLevel(WidgetTester tester) {
  return tester
      .widget<DropdownButtonFormField<PlanGoalLevel>>(
        find.byKey(const ValueKey('planGoalLevelField')),
      )
      .initialValue;
}

void _changeLevel(WidgetTester tester, PlanGoalLevel level) {
  tester
      .widget<DropdownButtonFormField<PlanGoalLevel>>(
        find.byKey(const ValueKey('planGoalLevelField')),
      )
      .onChanged!(level);
}
