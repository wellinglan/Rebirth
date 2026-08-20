import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/experience_preview/presentation/widgets/wellbeing_rating_field.dart';

void main() {
  test(
    'rating colors move from soft red through warm yellow to soft green',
    () {
      expect(wellbeingRatingColor(1), WellbeingRatingPalette.low);
      expect(wellbeingRatingColor(10), WellbeingRatingPalette.high);

      final middle = wellbeingRatingColor(5);
      expect(middle.r, closeTo(WellbeingRatingPalette.middle.r, 0.04));
      expect(middle.g, closeTo(WellbeingRatingPalette.middle.g, 0.04));
      expect(middle.b, closeTo(WellbeingRatingPalette.middle.b, 0.04));
      expect(WellbeingRatingPalette.inactive, const Color(0xFFFDFDFC));
    },
  );

  test('rating fraction clamps to the 1 to 10 range', () {
    expect(wellbeingRatingFraction(null), 0);
    expect(wellbeingRatingFraction(-20), 0);
    expect(wellbeingRatingFraction(1), 0);
    expect(wellbeingRatingFraction(10), 1);
    expect(wellbeingRatingFraction(50), 1);
  });

  testWidgets('null is visibly unrecorded and does not show a score thumb', (
    tester,
  ) async {
    await _pumpField(tester);

    expect(find.text('未记录'), findsOneWidget);
    expect(find.text('1 / 10'), findsNothing);
    final theme = tester.widget<SliderTheme>(find.byType(SliderTheme));
    expect(theme.data.thumbShape, SliderComponentShape.noThumb);
  });

  testWidgets('slider emits only bounded integer scores', (tester) async {
    final scores = <int?>[];
    await _pumpField(tester, onScoreChanged: scores.add);
    final slider = tester.widget<Slider>(find.byType(Slider));

    slider.onChanged!(1);
    slider.onChanged!(5.49);
    slider.onChanged!(5.51);
    slider.onChanged!(10);
    await tester.pump();

    expect(scores, [1, 5, 6, 10]);
    expect(scores.whereType<int>().every((score) => score >= 1), isTrue);
    expect(scores.whereType<int>().every((score) => score <= 10), isTrue);
  });

  testWidgets('clear restores null while preserving the description', (
    tester,
  ) async {
    final scores = <int?>[];
    final descriptions = <String>[];
    await _pumpField(
      tester,
      value: 7,
      description: '今天比较轻松',
      onScoreChanged: scores.add,
      onDescriptionChanged: descriptions.add,
    );

    await tester.tap(find.byKey(const ValueKey('心情Clear')));
    await tester.pump();

    expect(scores.last, isNull);
    expect(find.text('未记录'), findsOneWidget);
    expect(find.text('今天比较轻松'), findsOneWidget);
    expect(descriptions, isEmpty);
  });

  testWidgets('description changes independently from the score', (
    tester,
  ) async {
    final scores = <int?>[];
    final descriptions = <String>[];
    await _pumpField(
      tester,
      value: 4,
      onScoreChanged: scores.add,
      onDescriptionChanged: descriptions.add,
    );

    await tester.tap(find.byKey(const ValueKey('心情DescriptionAdd')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('心情Description')),
      '有一点紧张',
    );
    await tester.pump();

    expect(descriptions.last, '有一点紧张');
    expect(scores, isEmpty);
    expect(find.text('4 / 10'), findsOneWidget);
  });

  testWidgets('keyboard starts from a valid value and adjusts one point', (
    tester,
  ) async {
    final scores = <int?>[];
    await _pumpField(tester, onScoreChanged: scores.add);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.focusNode!.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(scores.last, 5);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(scores.last, 6);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(scores.last, 5);
  });

  testWidgets('enter can initialize an unrecorded score', (tester) async {
    final scores = <int?>[];
    await _pumpField(tester, onScoreChanged: scores.add);
    tester.widget<Slider>(find.byType(Slider)).focusNode!.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(scores.last, 5);
    expect(find.text('5 / 10'), findsOneWidget);
  });

  testWidgets('semantics includes field name score and total', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpField(tester, value: 7);

    final fieldSemantics = tester.getSemantics(
      find.byKey(const ValueKey('心情Semantics')),
    );
    final sliderSemantics = tester.getSemantics(
      find.byKey(const ValueKey('心情SliderSemantics')),
    );
    expect(fieldSemantics.label, contains('心情，7 / 10'));
    expect(sliderSemantics.label, contains('调整心情评分'));
    handle.dispose();
  });

  testWidgets('reduce motion removes the color transition duration', (
    tester,
  ) async {
    await _pumpField(tester, value: 8, disableAnimations: true);

    final animation = tester.widget<TweenAnimationBuilder<Color?>>(
      find.byKey(const ValueKey('心情ColorAnimation')),
    );
    expect(animation.duration, Duration.zero);
  });

  for (final width in [320.0, 360.0, 412.0, 720.0, 1200.0]) {
    testWidgets('rating field has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await _pumpField(tester, value: 10, width: width);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rating field has no overflow at 320px and TextScaler 2', (
    tester,
  ) async {
    await _pumpField(tester, value: 10, width: 320, textScale: 2);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpField(
  WidgetTester tester, {
  int? value,
  String description = '',
  ValueChanged<int?>? onScoreChanged,
  ValueChanged<String>? onDescriptionChanged,
  double width = 412,
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 700);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: WellbeingRatingField(
              label: '心情',
              icon: Icons.sentiment_satisfied_alt_outlined,
              value: value,
              description: description,
              descriptionHint: '用一句话说说今天的心情',
              onScoreChanged: onScoreChanged ?? (_) {},
              onDescriptionChanged: onDescriptionChanged ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
