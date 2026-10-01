import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/messaging/presentation/system_notifications_page.dart';

void main() {
  testWidgets('system notification bodies use equal vertical spacing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(750, 2500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const SystemNotificationsPage()),
    );
    expect(find.text('全部已读'), findsNothing);

    for (final title in ['签到获得', '预订状态更新', '服务维护提醒']) {
      final body = tester.widget<Column>(
        find.byKey(ValueKey('system-notice-body-$title')),
      );
      final titlePadding = body.children.first as Padding;
      expect(titlePadding.padding, const EdgeInsets.symmetric(vertical: 4));

      final titleCenter = tester.getCenter(find.text(title));
      expect(titleCenter.dx, closeTo(375, 1));
    }
  });
}
