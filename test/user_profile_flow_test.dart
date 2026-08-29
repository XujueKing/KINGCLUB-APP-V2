import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/user_profile_page.dart';

Widget _app(
  UserProfileRelationship relationship, {
  VoidCallback? onOpenSelfProfile,
  ValueChanged<String>? onOpenChat,
  ValueChanged<String>? onOpenSendRequest,
  VoidCallback? onSessionResetRequested,
}) {
  return MaterialApp(
    home: UserProfilePage(
      targetRef: 'contact-alice',
      initialRelationship: relationship,
      onOpenSelfProfile: onOpenSelfProfile,
      onOpenChat: onOpenChat,
      onOpenSendRequest: onOpenSendRequest,
      onSessionResetRequested: onSessionResetRequested,
    ),
  );
}

void main() {
  testWidgets('friend opens fake chat through typed callback', (tester) async {
    String? opened;
    await tester.pumpWidget(
      _app(UserProfileRelationship.friend, onOpenChat: (ref) => opened = ref),
    );
    await tester.tap(find.byKey(const ValueKey('user-profile-message')));
    expect(opened, 'contact-alice');
  });

  testWidgets('stranger starts request through callback', (tester) async {
    String? target;
    await tester.pumpWidget(
      _app(
        UserProfileRelationship.stranger,
        onOpenSendRequest: (ref) => target = ref,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('user-profile-add')));
    expect(target, 'contact-alice');
  });

  testWidgets('blocked user requires confirmation and remains stranger', (
    tester,
  ) async {
    await tester.pumpWidget(_app(UserProfileRelationship.blockedByMe));
    await tester.tap(find.byKey(const ValueKey('user-profile-unblock')));
    await tester.pumpAndSettle();
    expect(find.text('解除后不会自动恢复好友关系，需要重新发送好友申请。'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('user-profile-confirm-unblock')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('user-profile-add')), findsOneWidget);
  });

  testWidgets('expired preview is read only', (tester) async {
    await tester.pumpWidget(_app(UserProfileRelationship.previewExpired));
    expect(find.text('临时资料预览已过期'), findsOneWidget);
    expect(find.byKey(const ValueKey('user-profile-details')), findsOneWidget);
    expect(find.byKey(const ValueKey('user-profile-add')), findsNothing);
  });

  testWidgets('partial profile supports fake retry', (tester) async {
    await tester.pumpWidget(_app(UserProfileRelationship.partial));
    await tester.tap(find.byKey(const ValueKey('user-profile-partial')));
    await tester.pump();
    expect(find.byKey(const ValueKey('user-profile-add')), findsOneWidget);
  });

  testWidgets('self profile redirects instead of friendship action', (
    tester,
  ) async {
    var redirected = false;
    await tester.pumpWidget(
      _app(
        UserProfileRelationship.self,
        onOpenSelfProfile: () => redirected = true,
      ),
    );
    await tester.pump();
    expect(redirected, isTrue);
    expect(find.text('这是你自己的主页'), findsOneWidget);
  });

  testWidgets('session invalid halts actions and requests reset', (
    tester,
  ) async {
    var reset = false;
    await tester.pumpWidget(
      _app(
        UserProfileRelationship.sessionInvalid,
        onSessionResetRequested: () => reset = true,
      ),
    );
    await tester.pump();
    expect(find.text('已停止资料操作，请重新登录。'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('user-profile-session-confirm')),
    );
    await tester.pumpAndSettle();
    expect(reset, isTrue);
  });

  testWidgets('local permission flow keeps display name and updates relation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(UserProfileRelationship.friend),
    );
    await tester.tap(find.byKey(const ValueKey('user-profile-permissions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relationship-block')));
    await tester.pumpAndSettle();

    expect(find.textContaining('与 艾琳 的好友关系'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('relationship-confirm-确认拉黑')),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('user-profile-unblock')), findsOneWidget);
    expect(find.byKey(const ValueKey('user-profile-message')), findsNothing);
  });

  testWidgets('local request result atomically becomes outgoing pending', (
    tester,
  ) async {
    await tester.pumpWidget(_app(UserProfileRelationship.stranger));
    await tester.tap(find.byKey(const ValueKey('user-profile-add')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('send-friend-remark')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      '艾琳',
    );

    await tester.tap(find.byKey(const ValueKey('send-friend-submit')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('user-profile-waiting')), findsOneWidget);
    expect(find.byKey(const ValueKey('user-profile-add')), findsNothing);
  });
}
