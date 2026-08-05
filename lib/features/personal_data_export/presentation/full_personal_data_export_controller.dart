import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/personal_data_export_providers.dart';
import '../domain/full_personal_data_export.dart';

enum FullPersonalDataExportPhase { idle, exporting, saved, cancelled, failed }

final class FullPersonalDataExportViewState {
  const FullPersonalDataExportViewState({
    this.phase = FullPersonalDataExportPhase.idle,
    this.moduleCount = 0,
    this.recordCount = 0,
    this.message,
  });

  final FullPersonalDataExportPhase phase;
  final int moduleCount;
  final int recordCount;
  final String? message;

  bool get isExporting => phase == FullPersonalDataExportPhase.exporting;
}

final fullPersonalDataExportControllerProvider =
    NotifierProvider.autoDispose<
      FullPersonalDataExportController,
      FullPersonalDataExportViewState
    >(FullPersonalDataExportController.new);

class FullPersonalDataExportController
    extends Notifier<FullPersonalDataExportViewState> {
  @override
  FullPersonalDataExportViewState build() =>
      const FullPersonalDataExportViewState();

  Future<FullPersonalDataExportViewState> export() async {
    if (state.isExporting) return state;
    state = const FullPersonalDataExportViewState(
      phase: FullPersonalDataExportPhase.exporting,
    );
    try {
      final result = await ref
          .read(fullPersonalDataExportServiceProvider)
          .export();
      if (!ref.mounted) return state;
      state = FullPersonalDataExportViewState(
        phase: result.disposition == FullPersonalDataExportDisposition.saved
            ? FullPersonalDataExportPhase.saved
            : FullPersonalDataExportPhase.cancelled,
        moduleCount: result.moduleCount,
        recordCount: result.recordCount,
      );
    } on FullPersonalDataExportException catch (error) {
      if (!ref.mounted) return state;
      state = FullPersonalDataExportViewState(
        phase: FullPersonalDataExportPhase.failed,
        message: _messageFor(error.failure),
      );
    } catch (_) {
      if (!ref.mounted) return state;
      state = const FullPersonalDataExportViewState(
        phase: FullPersonalDataExportPhase.failed,
        message: '导出失败，个人数据和应用状态均未改变，请重试。',
      );
    }
    return state;
  }

  String _messageFor(FullPersonalDataExportFailure failure) =>
      switch (failure) {
        FullPersonalDataExportFailure.accessDenied => '当前登录账号或会话已变化，未生成备份文件。',
        FullPersonalDataExportFailure.sourceUnavailable =>
          '本地个人数据暂时无法完整读取，未生成不完整的备份。',
        FullPersonalDataExportFailure.invalidData => '备份数据格式校验失败，未写入文件。',
        FullPersonalDataExportFailure.integrityCheckFailed =>
          '备份完整性校验失败，未写入文件。',
        FullPersonalDataExportFailure.storageUnavailable =>
          '文件未能保存，个人数据和应用状态均未改变，请重试。',
      };
}
