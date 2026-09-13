import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/friendship_pages.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  testWidgets(
    'accept waits for server confirmation and removes demonstration requests',
    (tester) async {
      final ack = Completer<Map<String, dynamic>>();
      var accepted = false;
      final repository = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000610') {
            expect(params, {'requestId': 'request-1', 'accept': true});
            await ack.future;
            accepted = true;
            return {'status': 'accepted'};
          }
          return {
            'items': [
              {
                'requestId': 'request-1',
                'requester': 'actual-peer',
                'recipient': 'me',
                'note': 'Hello',
                'createdDate': '2026-09-13T01:00:00Z',
                'requestStatus': accepted ? 'accepted' : 'pending',
              },
            ],
            'hasMore': false,
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FriendRequestsPage(
            realData: true,
            repository: repository,
            onOpenAddFriend: () {},
            onOpenChat: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('林晓悦'), findsNothing);
      await tester.tap(find.text('actual-peer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('friend-request-accept')));
      await tester.pumpAndSettle();
      expect(find.text('已添加'), findsNothing);
      ack.complete({});
      await tester.pumpAndSettle();
      expect(find.text('已添加'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
