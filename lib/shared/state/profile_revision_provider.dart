import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRevisionProvider = NotifierProvider<ProfileRevisionNotifier, int>(
  ProfileRevisionNotifier.new,
);

class ProfileRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}
