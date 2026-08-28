import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/blacklist_page.dart';
import 'package:kingclub/src/features/contacts/presentation/friend_remark_page.dart';
import 'package:kingclub/src/features/contacts/presentation/relationship_permissions_page.dart';

void main() {
  testWidgets('remark save error retains edited draft', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FriendRemarkPage(
          targetRef: 'contact-alice',
          initialRemark: '艾琳',
          signature: '周末见',
          initialScenario: FriendRemarkScenario.saveError,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('friend-remark-name')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('friend-remark-input-备注名')),
      '周末搭子',
    );
    await tester.tap(find.byKey(const ValueKey('friend-remark-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relationship-back-朋友资料')));
    await tester.pump();
    expect(find.text('保存失败，修改内容仍保留在当前页面'), findsOneWidget);
    expect(find.text('周末搭子'), findsOneWidget);
  });

  testWidgets('remark invalid session disables editing and resets', (
    tester,
  ) async {
    var reset = false;
    await tester.pumpWidget(
      MaterialApp(
        home: FriendRemarkPage(
          targetRef: 'contact-alice',
          initialRemark: '艾琳',
          signature: '周末见',
          initialScenario: FriendRemarkScenario.sessionInvalid,
          onSessionResetRequested: () => reset = true,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('friend-remark-session-confirm')),
    );
    await tester.pumpAndSettle();
    expect(reset, isTrue);
    await tester.tap(find.byKey(const ValueKey('friend-remark-name')));
    await tester.pump();
    expect(find.byKey(const ValueKey('friend-remark-input-备注名')), findsNothing);
  });

  testWidgets('permission mutation failure keeps page and relationship', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RelationshipPermissionsPage(
          targetRef: 'contact-alice',
          displayName: '艾琳',
          initialScenario: RelationshipPermissionsScenario.mutationError,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('relationship-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('relationship-confirm-确认删除')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('操作失败，好友关系和权限未改变'), findsOneWidget);
    expect(find.text('权限'), findsOneWidget);
  });

  testWidgets('offline permissions are read only but back remains available', (
    tester,
  ) async {
    var backed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RelationshipPermissionsPage(
          targetRef: 'contact-alice',
          displayName: '艾琳',
          initialScenario: RelationshipPermissionsScenario.offlineReadOnly,
          onBack: () => backed = true,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('relationship-messages-only')));
    await tester.tap(
      find.byKey(const ValueKey('relationship-permissions-back')),
    );
    expect(backed, isTrue);
  });

  testWidgets('blacklist load error can recover', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlacklistPage(
          initialScenario: BlacklistScenario.loadError,
          onOpenAddFriend: () {},
          onOpenUserProfile: (_) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('blacklist-load-error')), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    await tester.pump();
    expect(find.byKey(const ValueKey('blacklist-list')), findsOneWidget);
  });

  testWidgets('blacklist unblock failure keeps user', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlacklistPage(
          initialScenario: BlacklistScenario.unblockError,
          onOpenAddFriend: () {},
          onOpenUserProfile: (_) {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.byKey(const ValueKey('blacklist-switch-contact-alice')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('blacklist-confirm-unblock')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('解除失败，黑名单状态未改变'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('blacklist-contact-alice')),
      findsOneWidget,
    );
  });
}
