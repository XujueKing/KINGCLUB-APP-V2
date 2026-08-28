import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/send_friend_request_page.dart';

Widget _app({
  SendFriendRequestScenario scenario = SendFriendRequestScenario.success,
  VoidCallback? onSent,
  VoidCallback? onOpenChat,
  VoidCallback? onSessionResetRequested,
}) {
  return MaterialApp(
    home: SendFriendRequestPage(
      targetRef: 'contact-alice',
      targetName: '艾琳',
      initialScenario: scenario,
      onSent: onSent,
      onOpenChat: onOpenChat,
      onSessionResetRequested: onSessionResetRequested,
    ),
  );
}

void main() {
  testWidgets('success sends once through callback', (tester) async {
    var sent = 0;
    await tester.pumpWidget(_app(onSent: () => sent++));
    await tester.tap(find.byKey(const ValueKey('send-friend-submit')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(sent, 1);
  });

  testWidgets('already pending hides editor', (tester) async {
    await tester.pumpWidget(
      _app(scenario: SendFriendRequestScenario.alreadyPending),
    );
    expect(find.text('好友申请已发送'), findsOneWidget);
    expect(find.byKey(const ValueKey('send-friend-submit')), findsNothing);
  });

  testWidgets('existing friend can open chat', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      _app(
        scenario: SendFriendRequestScenario.alreadyFriends,
        onOpenChat: () => opened = true,
      ),
    );
    await tester.tap(find.text('发消息'));
    expect(opened, isTrue);
  });

  testWidgets('unknown result blocks duplicate completion', (tester) async {
    var sent = 0;
    await tester.pumpWidget(
      _app(
        scenario: SendFriendRequestScenario.resultUnknown,
        onSent: () => sent++,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('send-friend-submit')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('发送结果确认中，请勿重复提交'), findsOneWidget);
    expect(sent, 0);
  });

  testWidgets('submit error keeps draft', (tester) async {
    await tester.pumpWidget(
      _app(scenario: SendFriendRequestScenario.submitError),
    );
    final message = find.byKey(const ValueKey('send-friend-message'));
    await tester.enterText(message, '周末一起去 KingClub');
    await tester.tap(find.byKey(const ValueKey('send-friend-submit')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('发送失败，草稿已保留，请稍后重试'), findsOneWidget);
    expect(find.text('周末一起去 KingClub'), findsOneWidget);
  });

  testWidgets('unavailable target shows terminal state', (tester) async {
    await tester.pumpWidget(
      _app(scenario: SendFriendRequestScenario.targetUnavailable),
    );
    expect(find.text('暂时无法添加该用户'), findsOneWidget);
    expect(find.byKey(const ValueKey('send-friend-submit')), findsNothing);
  });

  testWidgets('invalid session clears private draft and resets', (
    tester,
  ) async {
    var reset = false;
    await tester.pumpWidget(
      _app(
        scenario: SendFriendRequestScenario.sessionInvalid,
        onSessionResetRequested: () => reset = true,
      ),
    );
    await tester.pump();
    expect(find.text('验证消息和私有备注已清理，请重新登录。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('send-friend-session-confirm')));
    await tester.pumpAndSettle();
    expect(reset, isTrue);
  });
}
