import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/theme/app_motion.dart';

void main() {
  testWidgets('motion respects the platform disable animations preference', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(AppMotion.responsive(context, AppMotion.standard), Duration.zero);
  });

  testWidgets('motion keeps the design duration when animations are enabled', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(
      AppMotion.responsive(context, AppMotion.emphasized),
      AppMotion.emphasized,
    );
  });
}
