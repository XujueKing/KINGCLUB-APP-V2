import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_details_page.dart';

void main() {
  testWidgets(
    'owner selects actual member, confirms, retries same request then loses owner controls',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      var owner = 'me';
      final calls = <Map<String, dynamic>>[];
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, params) async {
            if (id == 'K260913000619')
              return {
                'groupName': '群',
                'ownerAccount': owner,
                'metadataVersion': 7,
                'membershipVersion': 0,
                'members': [
                  {
                    'account': 'me',
                    'nickname': '本人',
                    'role': owner == 'me' ? 'owner' : 'member',
                  },
                  {
                    'account': 'actual-member',
                    'nickname': '朋友',
                    'role': owner == 'me' ? 'member' : 'owner',
                  },
                ],
              };
            if (id == 'K260913000621') return {'settings': {}};
            if (id == 'K260913000626') {
              calls.add(params);
              if (calls.length == 1) throw StateError('网络中断');
              owner = params['target'] as String;
              return {
                'groupId': 'real-group',
                'ownerAccount': owner,
                'metadataVersion': 8,
              };
            }
            throw StateError(id);
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDetailsPage(groupId: 'real-group', repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> choose() async {
        await tester.tap(find.byKey(const ValueKey('group-transfer')));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(SimpleDialogOption, '本人'), findsNothing);
        await tester.tap(find.widgetWithText(SimpleDialogOption, '朋友'));
        await tester.pumpAndSettle();
      }

      await choose();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      for (var i = 0; i < 2; i++) {
        await choose();
        await tester.tap(find.byKey(const ValueKey('group-transfer-confirm')));
        await tester.pumpAndSettle();
      }
      expect(calls[0]['requestId'], calls[1]['requestId']);
      expect(calls[1]['target'], 'actual-member');
      expect(calls[1]['expectedVersion'], 7);
      expect(find.byKey(const ValueKey('group-transfer')), findsNothing);
      expect(find.text('退出群聊'), findsOneWidget);
      expect(find.text('解散群聊'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
