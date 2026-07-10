import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/utils/date_time_service.dart';

final dateTimeServiceProvider = Provider<DateTimeService>(
  (ref) => const DateTimeService(),
);
