import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/friend_discovery_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  testWidgets(
    'add friends provides real entry points and validates empty search',
    (tester) async {
      final calls = <String>[];
      final repo = MessagingRepository(
        account: 'tester',
        call: (id, p) async {
          calls.add(id);
          return {'items': []};
        },
      );
      var scanned = false;
      await tester.pumpWidget(
        MaterialApp(
          home: FriendDiscoveryPage(
            repository: repo,
            onOpenScanner: () async {
              scanned = true;
            },
            onOpenPersonalQr: () {},
          ),
        ),
      );
      for (final title in ['扫一扫', '交友查询', '雷达', '面对面建群', '我的二维码']) {
        expect(find.text(title), findsOneWidget);
      }
      await tester.tap(find.byType(TextField));
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(find.text('请输入账号或手机号码'), findsOneWidget);
      expect(calls, isEmpty);
      await tester.tap(find.text('扫一扫'));
      expect(scanned, isTrue);
      await tester.enterText(find.byType(TextField), 'member-example');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(calls, ['K260930000901']);
      expect(find.text('暂未找到符合条件的朋友'), findsOneWidget);
      for (final title in ['扫一扫', '交友查询', '雷达', '面对面建群', '我的二维码']) {
        expect(find.text(title), findsNothing);
      }
      await tester.tap(find.byTooltip('清除搜索'));
      await tester.pump();
      expect(find.text('扫一扫'), findsOneWidget);
      expect(find.text('暂未找到符合条件的朋友'), findsNothing);
    },
  );
  testWidgets(
    'discovery filters are submitted and radar does not publish on entry',
    (tester) async {
      Map<String, dynamic>? params;
      final repo = MessagingRepository(
        account: 'tester',
        call: (id, p) async {
          params = p;
          return {'items': []};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FriendDiscoveryPage(
            mode: FriendDiscoveryMode.browse,
            repository: repo,
          ),
        ),
      );
      await tester.tap(find.text('女'));
      await tester.pump();
      await tester.tap(find.text('查找朋友'));
      await tester.pumpAndSettle();
      expect(params?['gender'], 2);
      expect(params?['minAge'], 18);
      params = null;
      await tester.pumpWidget(
        MaterialApp(
          home: FriendDiscoveryPage(
            key: const ValueKey('radar'),
            mode: FriendDiscoveryMode.radar,
            repository: repo,
          ),
        ),
      );
      await tester.pump();
      expect(params, isNull);
      expect(find.text('开启雷达'), findsOneWidget);
    },
  );
}
