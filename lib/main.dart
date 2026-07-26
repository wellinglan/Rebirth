import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app/rebirth_app.dart';
import 'core/config/server_endpoint_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await container.read(serverEndpointControllerProvider.future);

  runApp(
    UncontrolledProviderScope(container: container, child: const RebirthApp()),
  );
}
