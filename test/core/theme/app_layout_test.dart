import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/theme/app_layout.dart';

void main() {
  test('layout tokens expose stable page, card, and field rhythm', () {
    expect(AppSpacing.xxs, lessThan(AppSpacing.xs));
    expect(AppSpacing.xs, lessThan(AppSpacing.sm));
    expect(AppSpacing.sm, lessThan(AppSpacing.md));
    expect(AppSpacing.md, lessThan(AppSpacing.lg));
    expect(AppSpacing.lg, lessThan(AppSpacing.xl));
    expect(AppSpacing.xl, lessThan(AppSpacing.xxl));
    expect(AppLayout.pagePadding.left, 20);
    expect(AppLayout.pagePadding.top, 16);
    expect(AppLayout.pagePadding.bottom, 24);
    expect(AppLayout.sectionGap, 24);
    expect(AppLayout.cardGap, 12);
    expect(AppLayout.fieldGap, 16);
    expect(AppLayout.minimumTouchTarget, 48);
    expect(AppLayout.pagePaddingFor(320).left, 16);
    expect(AppLayout.pagePaddingFor(720).left, 20);
    expect(AppLayout.pagePaddingFor(1200).left, 32);
    expect(AppLayout.usesNavigationRail(839), isFalse);
    expect(AppLayout.usesNavigationRail(840), isTrue);
    expect(AppLayout.usesExpandedNavigation(1200, 1), isTrue);
    expect(AppLayout.usesExpandedNavigation(1200, 2), isFalse);
  });
}
