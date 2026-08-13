import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/theme/app_theme.dart';
import 'package:rebirth/core/widgets/app_page.dart';
import 'package:rebirth/core/widgets/app_state_view.dart';

void main() {
  for (final width in <double>[320, 360, 412, 720, 1200]) {
    testWidgets('foundation widgets fit ${width.toInt()}px at text scale 2', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: const TextScaler.linear(2),
            ),
            child: const Scaffold(
              body: AppScrollablePage(
                child: AppMessageState(
                  icon: Icons.cloud_off_outlined,
                  title: '当前内容暂时无法加载',
                  message: '已保存的本地内容不会丢失，请稍后重新尝试。',
                  actionLabel: '重新加载',
                  onAction: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('当前内容暂时无法加载'), findsOneWidget);
      expect(find.text('重新加载'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView).first,
      );
      final expectedHorizontal = width < 600
          ? 16
          : width < 1200
          ? 20
          : 32;
      expect(scroll.padding?.horizontal, expectedHorizontal * 2);
    });
  }
}

void _noop() {}
