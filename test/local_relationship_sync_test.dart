import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/contacts/presentation/contacts_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/contacts/presentation/friendship_pages.dart';

void main() {
  test('successful local mutations notify only their account', () async {
    final mine = <String?>[], other = <String?>[];
    final a = MessagingRepository.relationshipChanges('a').listen(mine.add);
    final b = MessagingRepository.relationshipChanges('b').listen(other.add);
    addTearDown(a.cancel);
    addTearDown(b.cancel);
    var fail = false;
    final repo = MessagingRepository(
      account: 'a',
      call: (_, _) async {
        if (fail) throw StateError('offline');
        return {'saved': true};
      },
    );
    await repo.setRelationship('peer', 'block');
    await repo.resolveRequest('request', accept: true);
    await repo.requestFromQr(code: 'code', requestId: 'request');
    fail = true;
    await expectLater(
      repo.setRelationship('peer', 'unblock'),
      throwsStateError,
    );
    await Future<void>.delayed(Duration.zero);
    expect(mine, ['peer', null, null]);
    expect(other, isEmpty);
  });

  testWidgets(
    'local relationship change refreshes requests without websocket and coalesces bursts',
    (tester) async {
      var reads = 0;
      final pending = Completer<Map<String, dynamic>>();
      Map<String, dynamic> rows(String name) => {
        'items': [
          {
            'requestId': 'request',
            'requester': name,
            'recipient': 'a',
            'note': '',
            'createdDate': '2026-09-17',
            'requestStatus': 'pending',
          },
        ],
        'hasMore': false,
      };
      final repo = MessagingRepository(
        account: 'a',
        call: (id, _) async {
          if (id != 'K260913000611') return {'saved': true};
          reads++;
          if (reads == 2) return pending.future;
          return rows(reads == 1 ? 'before' : 'after');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FriendRequestsPage(
            realData: true,
            repository: repo,
            events: const Stream.empty(),
            onOpenAddFriend: () {},
            onOpenChat: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('before'), findsOneWidget);
      for (var i = 0; i < 15; i++) {
        await repo.setRelationship('peer', 'follow');
      }
      await tester.pump();
      expect(reads, 2);
      expect(find.text('before'), findsOneWidget);
      pending.complete(rows('intermediate'));
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(find.text('after'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await repo.setRelationship('peer', 'follow');
      await tester.pumpAndSettle();
      expect(reads, 3);
    },
  );
  testWidgets(
    'accept updates mounted contacts and request badge without realtime',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      var accepted = false;
      final badges = <int>[];
      final repo = MessagingRepository(
        account: 'local-contact',
        call: (id, _) async {
          if (id == 'K260913000610') {
            accepted = true;
            return {'status': 'accepted'};
          }
          if (id == 'K260913000608')
            return {
              'items': [
                if (accepted)
                  {'peer': 'new-peer', 'nickname': 'New local friend'},
              ],
              'hasMore': false,
            };
          if (id == 'K260913000611')
            return {
              'items': [
                if (!accepted)
                  {
                    'requestId': 'request',
                    'recipient': 'local-contact',
                    'requestStatus': 'pending',
                  },
              ],
              'hasMore': false,
            };
          return {'items': [], 'groups': [], 'hasMore': false};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactsPage(
              active: true,
              realData: true,
              repository: repo,
              onIntent: (_) {},
              onPendingRequestsChanged: badges.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(badges.last, 1);
      expect(find.text('New local friend'), findsNothing);
      await repo.resolveRequest('request', accept: true);
      await tester.pumpAndSettle();
      expect(badges.last, 0);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('New local friend'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
