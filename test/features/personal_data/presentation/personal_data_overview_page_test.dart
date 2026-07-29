import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:rebirth/features/personal_data/application/personal_data_provider_registry.dart';
import 'package:rebirth/features/personal_data/application/personal_data_providers.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_contribution.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_fact.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_identifier.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_item.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_provider.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_provider_descriptor.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_quality.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_query.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_value.dart';
import 'package:rebirth/features/personal_data/presentation/personal_data_overview_page.dart';

void main() {
  testWidgets('loading state is visible while a provider is pending', (
    tester,
  ) async {
    final gate = Completer<PersonalDataContribution>();
    final provider = _UiProvider('future.pending', result: gate.future);
    await _pumpPage(tester, [provider]);

    expect(
      find.byKey(const ValueKey('personalDataLoadingState')),
      findsOneWidget,
    );
    gate.complete(provider.contribution(_query()));
    await tester.pumpAndSettle();
  });

  testWidgets('five sources and a future provider render generically', (
    tester,
  ) async {
    final providers = [
      _UiProvider('rebirth.profile', displayName: '个人资料', order: 10),
      _UiProvider('rebirth.plan', displayName: '计划', order: 20),
      _UiProvider('rebirth.today', displayName: '今日', order: 30),
      _UiProvider('rebirth.journal', displayName: '复盘', order: 40),
      _UiProvider(
        'rebirth.health',
        displayName: '健康',
        order: 5,
        sensitivity: PersonalDataSensitivity.highlySensitive,
        factText: '本地敏感指标',
      ),
      _UiProvider('future.growth', displayName: '未来成长', order: 60),
    ];
    await _pumpPage(tester, providers);
    await tester.pumpAndSettle();

    for (final provider in providers) {
      expect(
        find.byKey(
          ValueKey(
            'personalDataSource_${provider.descriptor.providerId.value}',
          ),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('未来成长'), findsWidgets);
    expect(find.text('本地敏感指标'), findsNothing);

    final sensitiveExpansion = find.byKey(
      const ValueKey('sensitiveSourceExpansion_rebirth.health'),
    );
    await tester.scrollUntilVisible(
      sensitiveExpansion,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(sensitiveExpansion);
    await tester.pumpAndSettle();
    expect(find.text('本地敏感指标'), findsOneWidget);
  });

  testWidgets('date actions and manual refresh work without network UI', (
    tester,
  ) async {
    final provider = _UiProvider('future.growth');
    await _pumpPage(tester, [provider]);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('personalDataPreviousDateButton')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('personalDataSelectedDate')))
          .data,
      '2026-07-28',
    );

    await tester.tap(find.byKey(const ValueKey('personalDataTodayButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('personalDataRefreshButton')));
    await tester.pumpAndSettle();

    expect(provider.calls, 4);
    expect(find.textContaining('不进行云同步或 AI 分析'), findsOneWidget);
  });

  testWidgets('partial provider failure keeps healthy source visible', (
    tester,
  ) async {
    final healthy = _UiProvider('future.healthy', displayName: '正常来源');
    final failed = _UiProvider(
      'future.failed',
      displayName: '失败来源',
      error: StateError('sensitive stack detail'),
    );
    await _pumpPage(tester, [failed, healthy]);
    await tester.pumpAndSettle();

    expect(find.text('正常来源'), findsWidgets);
    expect(find.text('失败来源'), findsOneWidget);
    expect(find.textContaining('1 个本地数据来源暂不可用'), findsOneWidget);
    expect(find.textContaining('sensitive stack detail'), findsNothing);
  });

  testWidgets('privacy-safe rendering exposes no raw JSON or full UUID', (
    tester,
  ) async {
    final provider = _UiProvider(
      'rebirth.journal',
      displayName: '复盘',
      factText: '安全元数据',
    );
    await _pumpPage(tester, [provider]);
    await tester.pumpAndSettle();

    expect(find.textContaining('{'), findsNothing);
    expect(
      find.textContaining('00000000-0000-4000-8000-000000000001'),
      findsNothing,
    );
    expect(find.textContaining('Token'), findsNothing);
    expect(find.textContaining('Endpoint'), findsNothing);
  });

  for (final width in [320.0, 360.0, 412.0, 720.0, 840.0, 1200.0]) {
    testWidgets('${width.toInt()}px layout has no overflow', (tester) async {
      await _pumpPage(tester, [
        _UiProvider('rebirth.profile', displayName: '个人资料'),
        _UiProvider('rebirth.plan', displayName: '计划'),
        _UiProvider('rebirth.today', displayName: '今日'),
        _UiProvider('rebirth.journal', displayName: '复盘'),
        _UiProvider(
          'rebirth.health',
          displayName: '健康',
          sensitivity: PersonalDataSensitivity.highlySensitive,
        ),
      ], size: Size(width, 850));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('personalDataSource_rebirth.health')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TextScaler 2.0 remains scrollable with readable semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpPage(
      tester,
      [
        _UiProvider('future.growth', displayName: '未来成长数据来源'),
        _UiProvider(
          'rebirth.health',
          displayName: '健康',
          sensitivity: PersonalDataSensitivity.highlySensitive,
        ),
      ],
      size: const Size(320, 700),
      textScale: 2,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '当前选择日期 2026-07-29',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '仅汇总当前账号的本地数据，不进行云同步或 AI 分析',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  List<PersonalDataProvider> providers, {
  Size size = const Size(900, 1000),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAuthStateProvider.overrideWithValue(
          const AsyncData(
            AppAuthState(
              status: AppAuthStatus.authenticatedOffline,
              localUserId: 'local-user-a',
            ),
          ),
        ),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 29, 10)),
        ),
        personalDataProviderRegistryProvider.overrideWithValue(
          PersonalDataProviderRegistry(providers),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const PersonalDataOverviewPage(),
      ),
    ),
  );
}

final class _UiProvider implements PersonalDataProvider {
  _UiProvider(
    String id, {
    this.displayName = '测试来源',
    this.order = 10,
    this.sensitivity = PersonalDataSensitivity.standardPrivate,
    this.factText = '本地数据',
    this.result,
    this.error,
  }) : descriptor = PersonalDataProviderDescriptor(
         providerId: PersonalDataProviderId(id),
         displayName: displayName,
         description: '通用本地数据来源',
         providerSchemaVersion: 1,
         capabilities: {PersonalDataCapability.timeline},
         defaultSensitivity: sensitivity,
         displayOrder: order,
       );

  final String displayName;
  final int order;
  final PersonalDataSensitivity sensitivity;
  final String factText;
  final Future<PersonalDataContribution>? result;
  final Object? error;
  int calls = 0;

  @override
  final PersonalDataProviderDescriptor descriptor;

  @override
  Future<PersonalDataContribution> collect(PersonalDataQuery query) {
    calls++;
    if (error != null) return Future.error(error!);
    return result ?? Future.value(contribution(query));
  }

  PersonalDataContribution contribution(PersonalDataQuery query) {
    return PersonalDataContribution(
      providerId: descriptor.providerId,
      providerSchemaVersion: 1,
      coveredTimeRange: query.timeRange,
      capabilities: descriptor.capabilities,
      sensitivity: sensitivity,
      quality: const PersonalDataQuality.complete(),
      items: [
        PersonalDataItem(
          id: PersonalDataItemId('${descriptor.providerId.value}.item'),
          kind: PersonalDataItemKind('${descriptor.providerId.value}.entry'),
          title: displayName,
          localDate: query.timeRange.startLocalDate,
          facts: [
            PersonalDataFact(
              key: PersonalDataFactKey('${descriptor.providerId.value}.fact'),
              label: '摘要',
              value: PersonalDataTextValue(factText),
              sensitivity: sensitivity,
            ),
          ],
          sensitivity: sensitivity,
          quality: const PersonalDataQuality.complete(),
        ),
      ],
      generatedAtUtc: query.requestedAtUtc,
    );
  }
}

PersonalDataQuery _query() {
  return PersonalDataQuery.daily(
    localDate: '2026-07-29',
    requestedAtUtc: DateTime.utc(2026, 7, 29, 3),
  );
}
