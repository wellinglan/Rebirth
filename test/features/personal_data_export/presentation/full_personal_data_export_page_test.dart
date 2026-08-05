import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/personal_data_export/data/personal_data_export_providers.dart';
import 'package:rebirth/features/personal_data_export/domain/full_personal_data_export.dart';
import 'package:rebirth/features/personal_data_export/presentation/full_personal_data_export_page.dart';

void main() {
  testWidgets(
    'confirmation, saving state, and success feedback form a closed loop',
    (tester) async {
      final completer = Completer<FullPersonalDataExportResult>();
      final service = _FakeService([() => completer.future]);
      await _pump(tester, service: service);

      expect(find.text('完整个人数据备份'), findsOneWidget);
      expect(find.textContaining('未加密的明文 JSON'), findsOneWidget);
      expect(find.textContaining('不支持恢复'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('startFullPersonalDataExportButton')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('fullPersonalDataExportConfirmationDialog')),
        findsOneWidget,
      );
      expect(find.textContaining('Journal、Health 和 AI 报告正文'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('confirmFullPersonalDataExportButton')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('fullPersonalDataExportProgress')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('startFullPersonalDataExportButton')),
            )
            .onPressed,
        isNull,
      );

      completer.complete(
        const FullPersonalDataExportResult(
          disposition: FullPersonalDataExportDisposition.saved,
          moduleCount: 7,
          recordCount: 23,
        ),
      );
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      expect(find.text('完整个人数据已保存，共 23 条记录。'), findsOneWidget);
    },
  );

  testWidgets(
    'dialog cancellation performs no export and Android Back is safe',
    (tester) async {
      final service = _FakeService([]);
      await _pump(tester, service: service);
      await tester.tap(
        find.byKey(const ValueKey('startFullPersonalDataExportButton')),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(service.calls, 0);
      expect(
        find.byKey(const ValueKey('fullPersonalDataExportConfirmationDialog')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('fullPersonalDataExportPage')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'failure preserves the page, hides internals, and permits retry',
    (tester) async {
      final service = _FakeService([
        () => Future.error(StateError(r'C:\Users\private\backup.json')),
        () => Future.value(
          const FullPersonalDataExportResult(
            disposition: FullPersonalDataExportDisposition.saved,
            moduleCount: 7,
            recordCount: 2,
          ),
        ),
      ]);
      await _pump(tester, service: service);

      await _confirmExport(tester);
      expect(
        find.byKey(const ValueKey('fullPersonalDataExportPage')),
        findsOneWidget,
      );
      expect(find.textContaining('个人数据和应用状态均未改变'), findsWidgets);
      expect(find.textContaining('private'), findsNothing);

      await _confirmExport(tester);
      expect(service.calls, 2);
      expect(find.text('完整个人数据已保存，共 2 条记录。'), findsOneWidget);
    },
  );

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('$width px with TextScaler 2.0 has no overflow', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 760);
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        service: _FakeService([]),
        textScaler: const TextScaler.linear(2),
      );

      expect(find.byType(Scrollable), findsWidgets);
      await tester.ensureVisible(
        find.byKey(const ValueKey('startFullPersonalDataExportButton')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Windows keyboard can open the confirmation dialog', (
    tester,
  ) async {
    await _pump(tester, service: _FakeService([]));
    await tester.ensureVisible(
      find.byKey(const ValueKey('startFullPersonalDataExportButton')),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('fullPersonalDataExportConfirmationDialog')),
      findsOneWidget,
    );
  });
}

Future<void> _confirmExport(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey('startFullPersonalDataExportButton')),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('confirmFullPersonalDataExportButton')),
  );
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required FullPersonalDataExportService service,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        fullPersonalDataExportServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const FullPersonalDataExportPage(),
      ),
    ),
  );
}

final class _FakeService implements FullPersonalDataExportService {
  _FakeService(this.results);

  final List<Future<FullPersonalDataExportResult> Function()> results;
  int calls = 0;

  @override
  Future<FullPersonalDataExportResult> export() {
    calls += 1;
    return results.removeAt(0)();
  }
}
