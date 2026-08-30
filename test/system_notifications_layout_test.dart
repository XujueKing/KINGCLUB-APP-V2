import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/messaging/presentation/system_notifications_page.dart';

void main() {
  testWidgets('system notification bodies use equal vertical spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KingTheme.dark, home: const SystemNotificationsPage()),
    );

    for (final title in ['签到获得', '预订状态更新', '服务维护提醒']) {
      final body = tester.widget<Padding>(
        find.byKey(ValueKey('system-notice-body-$title')),
      );
      expect(body.padding, const EdgeInsets.symmetric(vertical: 16));

      final titleCenter = tester.getCenter(find.text(title));
      expect(titleCenter.dx, closeTo(400, 1));
    }
  });
}
