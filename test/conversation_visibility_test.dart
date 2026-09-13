import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';

void main() {
  testWidgets('hide and block perform distinct local actions', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationsPage(
            active: true,
            systemUnreadCount: 0,
            initialFriendUnreadCount: 1,
            onFriendUnreadChanged: (_) {},
            onOpenContacts: () {},
            onAddFriend: () {},
            onOpenSystemNotifications: () {},
            onOpenDirectChat: () => opens++,
          ),
        ),
      ),
    );
    Future<void> menu() async {
      await tester.longPress(find.text('卡座搭子'));
      await tester.pumpAndSettle();
    }

    await menu();
    expect(find.text('会话摘要改为只读'), findsNothing);
    await tester.tap(find.text('拉黑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('卡座搭子'));
    await tester.pumpAndSettle();
    expect(opens, 0);
    await menu();
    await tester.tap(find.text('解除拉黑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('卡座搭子'));
    await tester.pumpAndSettle();
    expect(opens, 1);
    await menu();
    await tester.tap(find.text('不显示'));
    await tester.pumpAndSettle();
    expect(find.text('卡座搭子'), findsNothing);
    expect(find.text('KING CLUB'), findsOneWidget);
  });
}
