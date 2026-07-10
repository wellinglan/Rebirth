import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/app/rebirth_app.dart';

void main() {
  testWidgets('renders the app shell and switches destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: RebirthApp()));
    await tester.pumpAndSettle();

    expect(find.text('今天，从关注当下开始。'), findsOneWidget);

    await tester.tap(find.text('复盘'));
    await tester.pumpAndSettle();

    expect(find.text('留一点空间，回望今天。'), findsOneWidget);
  });
}
