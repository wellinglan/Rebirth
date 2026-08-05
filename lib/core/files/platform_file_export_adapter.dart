import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

import 'file_export.dart';

typedef PlatformSaveFileCallback =
    Future<String?> Function({
      required String dialogTitle,
      required String fileName,
      required List<String> allowedExtensions,
      required String mimeType,
      required Uint8List bytes,
    });

final class PlatformFileExportAdapter implements FileExportAdapter {
  PlatformFileExportAdapter({PlatformSaveFileCallback? saveFile})
    : _saveFile = saveFile ?? _defaultSaveFile;

  final PlatformSaveFileCallback _saveFile;

  @override
  Future<FileExportDisposition> save(FileExportRequest request) async {
    final result = await _saveFile(
      dialogTitle: request.dialogTitle,
      fileName: request.fileName,
      allowedExtensions: [request.extension],
      mimeType: request.mimeType,
      bytes: request.bytes,
    );
    return result == null
        ? FileExportDisposition.cancelled
        : FileExportDisposition.saved;
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
    throw UnsupportedError('File export is not supported on this platform.');
  }
}
