import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/presentation/conversations_page.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_details_page.dart';

void main() {
  testWidgets('muted unread uses a dot; normal counts cap at 99', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Widget page(bool muted, int unread) => MaterialApp(
      home: Scaffold(
        body: ConversationsPage(
          key: ValueKey('$muted-$unread'),
          active: true,
          friendMuted: muted,
          systemUnreadCount: 0,
          initialFriendUnreadCount: unread,
          onFriendUnreadChanged: (_) {},
          onOpenContacts: () {},
          onAddFriend: () {},
          onOpenSystemNotifications: () {},
          onOpenDirectChat: () {},
        ),
      ),
    );
    await tester.pumpWidget(page(false, 120));
    await tester.pumpAndSettle();
    expect(find.text('99'), findsOneWidget);
    expect(find.text('99+'), findsNothing);
    expect(find.byKey(const ValueKey('conversation-muted-icon')), findsNothing);
    await tester.pumpWidget(page(true, 120));
    await tester.pumpAndSettle();
    final dot = find.byKey(const ValueKey('conversation-unread-badge'));
    expect(dot, findsOneWidget);
    expect(find.descendant(of: dot, matching: find.byType(Text)), findsNothing);
    expect(tester.getSize(dot).width, closeTo(16 * 393 / 750, .01));
    final mutedIcon = find.byKey(const ValueKey('conversation-muted-icon'));
    expect(
      tester.getTopLeft(mutedIcon).dy,
      greaterThan(tester.getBottomLeft(find.text('21:08')).dy),
    );
    expect(
      tester.getCenter(mutedIcon).dy,
      closeTo(tester.getCenter(find.text('周末 KING CLUB 见？')).dy, .01),
    );
    await tester.pumpWidget(page(true, 0));
    await tester.pumpAndSettle();
    expect(dot, findsNothing);
    expect(mutedIcon, findsOneWidget);
    await tester.enterText(find.byType(TextField), '  king  ');
    await tester.pumpAndSettle();
    expect(find.text('KING CLUB'), findsOneWidget);
    expect(find.text('卡座搭子'), findsNothing);
    await tester.enterText(find.byType(TextField), '不存在的会话');
    await tester.pumpAndSettle();
    expect(find.text('未找到相关聊天'), findsOneWidget);
    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pumpAndSettle();
    expect(find.text('卡座搭子'), findsOneWidget);
    expect(mutedIcon, findsOneWidget);
  });
  testWidgets('details initializes mute and reports changes', (tester) async {
    bool? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: DirectChatDetailsPage(
          peerName: '测试会话',
          initialMuted: true,
          onMutedChanged: (value) => changed = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('direct-chat-details-muted'));
    expect(tester.widget<Switch>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(changed, isFalse);
  });
}
