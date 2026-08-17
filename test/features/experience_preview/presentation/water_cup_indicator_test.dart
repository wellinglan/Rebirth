import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/experience_preview/presentation/widgets/water_cup_indicator.dart';

void main() {
  test('water level fraction clamps without changing the exact value', () {
    expect(waterLevelFraction(null, 2000), 0);
    expect(waterLevelFraction(0, 2000), 0);
    expect(waterLevelFraction(1000, 2000), 0.5);
    expect(waterLevelFraction(2000, 2000), 1);
    expect(waterLevelFraction(2500, 2000), 1);
  });

  testWidgets('null, zero and exact ml remain distinct', (tester) async {
    await _pump(tester, value: null);
    expect(find.text('未记录'), findsOneWidget);

    await _pump(tester, value: 0);
    expect(find.text('0 ml'), findsOneWidget);

    await _pump(tester, value: 250);
    expect(find.text('250 ml'), findsOneWidget);
  });

  testWidgets('value beyond visual capacity keeps its exact text', (
    tester,
  ) async {
    await _pump(tester, value: 2500);
    expect(find.text('2500 ml'), findsOneWidget);
    expect(find.textContaining('达标'), findsNothing);
  });

  testWidgets('reduced motion uses an immediate water transition', (
    tester,
  ) async {
    await _pump(tester, value: 500, disableAnimations: true);
    final tween = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>),
    );
    expect(tween.duration, Duration.zero);
  });

  testWidgets('semantics contains exact current water amount', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, value: 750);
    expect(find.bySemanticsLabel('当前饮水量 750 毫升'), findsOneWidget);
    semantics.dispose();
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required int? value,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: WaterCupIndicator(waterIntakeMl: value)),
      ),
    ),
  );
  await tester.pump();
}
