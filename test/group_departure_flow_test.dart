import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_details_page.dart';

void main() {
  for (final owner in [false, true]) {
    testWidgets(
      'departure confirms then waits for acknowledgement owner=$owner',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        Map<String, dynamic>? sent;
        bool? outcome;
        final ack = Completer<Map<String, dynamic>>();
        final repo = GroupChatRepository(
          MessagingRepository(
            account: 'me',
            call: (id, params) async {
              if (id == 'K260913000619')
                return {
                  'groupName': '测试群',
                  'ownerAccount': owner ? 'me' : 'other',
                  'membershipVersion': 3,
                  'metadataVersion': 0,
                  'members': [],
                };
              if (id == 'K260913000621') return {'settings': {}};
              if (id == 'K260913000625') {
                sent = params;
                return ack.future;
              }
              throw StateError(id);
            },
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    outcome = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute<bool>(
                        builder: (_) => GroupDetailsPage(
                          groupId: 'real-group',
                          repository: repo,
                        ),
                      ),
                    );
                  },
                  child: const Text('打开群'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开群'));
        await tester.pumpAndSettle();
        final button = find.byKey(const ValueKey('group-depart'));
        expect(find.text(owner ? '解散群聊' : '退出群聊'), findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(sent, isNull);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('group-depart-confirm')));
        await tester.pumpAndSettle();
        expect(sent, {
          'groupId': 'real-group',
          'action': owner ? 'dissolve' : 'leave',
          'membershipVersion': 3,
        });
        expect(find.byType(GroupDetailsPage), findsOneWidget);
        expect(outcome, isNull);
        ack.complete({'action': owner ? 'dissolve' : 'leave', 'changed': true});
        await tester.pumpAndSettle();
        expect(find.byType(GroupDetailsPage), findsNothing);
        expect(outcome, true);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
