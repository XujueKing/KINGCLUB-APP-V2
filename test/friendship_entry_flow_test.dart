import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/friendship_pages.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('add friend uses a short-lived fake QR without permanent id', (
    tester,
  ) async {
    var scannerCalls = 0;
    var personalQrCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AddFriendPage(
          onOpenScanner: () async => scannerCalls++,
          onOpenPersonalQr: () => personalQrCalls++,
        ),
      ),
    );

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('K456'), findsNothing);
    expect(find.textContaining('永久账号'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-friend-scan')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add-friend-personal-qr')));
    expect(scannerCalls, 1);
    expect(personalQrCalls, 1);
  });

  testWidgets('unavailable scanner stays on add friend page', (tester) async {
    var scannerCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AddFriendPage(
          initialScenario: AddFriendScenario.destinationUnavailable,
          onOpenScanner: () async => scannerCalls++,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('add-friend-scan')));
    await tester.pump();
    expect(scannerCalls, 0);
    expect(find.text('扫码入口暂时不可用，请稍后重试'), findsOneWidget);
  });

  testWidgets('add friend session invalid requests auth reset', (tester) async {
    var resetCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AddFriendPage(
          initialScenario: AddFriendScenario.sessionInvalid,
          onOpenScanner: () async {},
          onSessionResetRequested: () => resetCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-friend-session-dialog')), findsOne);
    await tester.tap(find.byKey(const ValueKey('add-friend-session-confirm')));
    await tester.pumpAndSettle();
    expect(resetCount, 1);
  });

  testWidgets('friend requests empty state keeps add friend recovery', (
    tester,
  ) async {
    var addCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FriendRequestsPage(
          initialScenario: FriendRequestsScenario.empty,
          onOpenAddFriend: () => addCalls++,
          onOpenChat: (_) {},
        ),
      ),
    );
    expect(find.byKey(const ValueKey('friend-requests-empty')), findsOneWidget);
    await tester.tap(find.text('添加好友'));
    expect(addCalls, 1);
  });

  testWidgets('offline friend request cache is read only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FriendRequestsPage(
          initialScenario: FriendRequestsScenario.offlineCached,
          onOpenAddFriend: () {},
          onOpenChat: (_) {},
        ),
      ),
    );
    expect(find.byKey(const ValueKey('friend-requests-offline')), findsOne);
    await tester.tap(find.byKey(const ValueKey('friend-request-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('friend-request-accept')), findsNothing);
  });

  testWidgets('friend request session invalid clears to auth reset', (
    tester,
  ) async {
    var resetCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FriendRequestsPage(
          initialScenario: FriendRequestsScenario.sessionInvalid,
          onOpenAddFriend: () {},
          onOpenChat: (_) {},
          onSessionResetRequested: () => resetCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('friend-requests-session-confirm')),
    );
    await tester.pumpAndSettle();
    expect(resetCount, 1);
  });
}
