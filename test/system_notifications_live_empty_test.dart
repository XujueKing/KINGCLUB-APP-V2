import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/presentation/system_notifications_page.dart';

void main() {
  testWidgets('live system inbox never presents sample transactions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SystemNotificationsPage(demo: false, initialUnreadCount: 0),
      ),
    );
    expect(find.text('暂无系统消息'), findsOneWidget);
    expect(find.text('签到获得'), findsNothing);
    expect(find.text('预订成功'), findsNothing);
  });
}
