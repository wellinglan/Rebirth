import 'dart:typed_data';

final class FileExportRequest {
  const FileExportRequest({
    required this.dialogTitle,
    required this.fileName,
    required this.extension,
    required this.mimeType,
    required this.bytes,
  });

  final String dialogTitle;
  final String fileName;
  final String extension;
  final String mimeType;
  final Uint8List bytes;
}

enum FileExportDisposition { saved, cancelled }

abstract interface class FileExportAdapter {
  Future<FileExportDisposition> save(FileExportRequest request);
}
