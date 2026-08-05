import 'dart:convert';
import 'dart:typed_data';

import 'package:rebirth/core/files/file_export.dart';
import 'package:rebirth/core/files/platform_file_export_adapter.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_file_export_adapter.dart';

typedef AiReportSaveFileCallback = PlatformSaveFileCallback;

final class PlatformAiReportExportAdapter implements AiReportFileExportAdapter {
  PlatformAiReportExportAdapter({
    FileExportAdapter? fileExportAdapter,
    AiReportSaveFileCallback? saveFile,
  }) : _fileExportAdapter =
           fileExportAdapter ?? PlatformFileExportAdapter(saveFile: saveFile);

  final FileExportAdapter _fileExportAdapter;

  @override
  Future<AiReportFileExportDisposition> save(AiReportExportFile file) async {
    final result = await _fileExportAdapter.save(
      FileExportRequest(
        dialogTitle: '保存 AI 报告导出文件',
        fileName: file.fileName,
        extension: file.extension,
        mimeType: file.mimeType,
        bytes: Uint8List.fromList(utf8.encode(file.content)),
      ),
    );
    return result == FileExportDisposition.saved
        ? AiReportFileExportDisposition.saved
        : AiReportFileExportDisposition.cancelled;
  }
}
