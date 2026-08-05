import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/files/file_export.dart';
import 'package:rebirth/core/files/platform_file_export_adapter.dart';

void main() {
  test('shared adapter forwards stable UTF-8 file metadata', () async {
    String? capturedTitle;
    String? capturedName;
    String? capturedMimeType;
    List<String>? capturedExtensions;
    Uint8List? capturedBytes;
    final adapter = PlatformFileExportAdapter(
      saveFile:
          ({
            required dialogTitle,
            required fileName,
            required allowedExtensions,
            required mimeType,
            required bytes,
          }) async {
            capturedTitle = dialogTitle;
            capturedName = fileName;
            capturedMimeType = mimeType;
            capturedExtensions = allowedExtensions;
            capturedBytes = bytes;
            return 'saved';
          },
    );

    final result = await adapter.save(
      FileExportRequest(
        dialogTitle: '保存备份',
        fileName: 'backup.json',
        extension: 'json',
        mimeType: 'application/json',
        bytes: Uint8List.fromList(utf8.encode('{"正文":"中文"}')),
      ),
    );

    expect(result, FileExportDisposition.saved);
    expect(capturedTitle, '保存备份');
    expect(capturedName, 'backup.json');
    expect(capturedMimeType, 'application/json');
    expect(capturedExtensions, ['json']);
    expect(utf8.decode(capturedBytes!), '{"正文":"中文"}');
  });

  test('null platform result means cancellation', () async {
    final adapter = PlatformFileExportAdapter(
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
        FileExportRequest(
          dialogTitle: '保存',
          fileName: 'backup.json',
          extension: 'json',
          mimeType: 'application/json',
          bytes: Uint8List(0),
        ),
      ),
      FileExportDisposition.cancelled,
    );
  });

  test(
    'platform write errors remain failures for the controller to sanitize',
    () {
      final adapter = PlatformFileExportAdapter(
        saveFile:
            ({
              required dialogTitle,
              required fileName,
              required allowedExtensions,
              required mimeType,
              required bytes,
            }) async => throw StateError('disk unavailable'),
      );

      expectLater(
        adapter.save(
          FileExportRequest(
            dialogTitle: '保存',
            fileName: 'backup.json',
            extension: 'json',
            mimeType: 'application/json',
            bytes: Uint8List(0),
          ),
        ),
        throwsStateError,
      );
    },
  );
}
