import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_reports/data/platform_ai_report_export_adapter.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export.dart';

void main() {
  test('adapter passes UTF-8 bytes and stable file metadata', () async {
    String? name;
    String? capturedMimeType;
    List<String>? extensions;
    Uint8List? capturedBytes;
    final adapter = PlatformAiReportExportAdapter(
      saveFile:
          ({
            required dialogTitle,
            required fileName,
            required allowedExtensions,
            required mimeType,
            required bytes,
          }) async {
            name = fileName;
            capturedMimeType = mimeType;
            extensions = allowedExtensions;
            capturedBytes = bytes;
            return 'saved';
          },
    );

    final result = await adapter.save(
      const AiReportExportFile(
        fileName: 'report.md',
        extension: 'md',
        mimeType: 'text/markdown',
        content: '中文正文',
      ),
    );

    expect(result, AiReportFileExportDisposition.saved);
    expect(name, 'report.md');
    expect(capturedMimeType, 'text/markdown');
    expect(extensions, ['md']);
    expect(utf8.decode(capturedBytes!), '中文正文');
  });

  test('null platform result is treated as user cancellation', () async {
    final adapter = PlatformAiReportExportAdapter(
      saveFile:
          ({
            required dialogTitle,
            required fileName,
            required allowedExtensions,
            required mimeType,
            required bytes,
          }) async => null,
    );

    expect(
      await adapter.save(
        const AiReportExportFile(
          fileName: 'reports.json',
          extension: 'json',
          mimeType: 'application/json',
          content: '{}',
        ),
      ),
      AiReportFileExportDisposition.cancelled,
    );
  });

  test('platform write errors remain failures', () async {
    final adapter = PlatformAiReportExportAdapter(
      saveFile:
          ({
            required dialogTitle,
            required fileName,
            required allowedExtensions,
            required mimeType,
            required bytes,
          }) async => throw StateError('disk unavailable'),
    );

    await expectLater(
      adapter.save(
        const AiReportExportFile(
          fileName: 'reports.json',
          extension: 'json',
          mimeType: 'application/json',
          content: '{}',
        ),
      ),
      throwsStateError,
    );
  });
}
