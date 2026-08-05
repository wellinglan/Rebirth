import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_export.dart';
import 'platform_file_export_adapter.dart';

final fileExportAdapterProvider = Provider<FileExportAdapter>(
  (ref) => PlatformFileExportAdapter(),
);
