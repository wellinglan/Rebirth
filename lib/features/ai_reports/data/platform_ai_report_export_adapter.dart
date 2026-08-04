import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_file_export_adapter.dart';

typedef AiReportSaveFileCallback =
    Future<String?> Function({
      required String dialogTitle,
      required String fileName,
      required List<String> allowedExtensions,
      required String mimeType,
      required Uint8List bytes,
    });

final class PlatformAiReportExportAdapter implements AiReportFileExportAdapter {
  PlatformAiReportExportAdapter({AiReportSaveFileCallback? saveFile})
    : _saveFile = saveFile ?? _defaultSaveFile;

  final AiReportSaveFileCallback _saveFile;

  @override
  Future<AiReportFileExportDisposition> save(AiReportExportFile file) async {
    final result = await _saveFile(
      dialogTitle: '保存 AI 报告导出文件',
      fileName: file.fileName,
      allowedExtensions: [file.extension],
      mimeType: file.mimeType,
      bytes: Uint8List.fromList(utf8.encode(file.content)),
    );
    return result == null
        ? AiReportFileExportDisposition.cancelled
        : AiReportFileExportDisposition.saved;
  }

  static Future<String?> _defaultSaveFile({
    required String dialogTitle,
    required String fileName,
    required List<String> allowedExtensions,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (Platform.isAndroid) {
      return FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          data: bytes,
          fileName: fileName,
          mimeTypesFilter: [mimeType],
          localOnly: false,
        ),
      );
    }
    if (Platform.isWindows) {
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          XTypeGroup(
            label: dialogTitle,
            extensions: allowedExtensions,
            mimeTypes: [mimeType],
          ),
        ],
      );
      if (location == null) return null;
      final file = XFile.fromData(bytes, mimeType: mimeType, name: fileName);
      await file.saveTo(location.path);
      return location.path;
    }
    throw UnsupportedError('AI report export is not supported here.');
  }
}
