import 'package:flutter_riverpod/flutter_riverpod.dart';

final healthRecordRevisionProvider =
    NotifierProvider<HealthRecordRevisionNotifier, int>(
      HealthRecordRevisionNotifier.new,
    );

class HealthRecordRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}
