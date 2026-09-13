import 'package:kingclub/src/core/session/secure_session_store.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/friendship_pages.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  testWidgets(
    'request events and reconnect refresh, logout rejects late data',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      var reads = 0;
      final late = Completer<Map<String, dynamic>>();
      Map<String, dynamic> snapshot(String peer) => {
        'items': [
          {
            'requestId': peer,
            'requester': peer,
            'recipient': 'me',
            'note': 'hello',
            'createdDate': '2026-09-13T01:00:00Z',
            'requestStatus': 'pending',
          },
        ],
        'hasMore': false,
      };
      final repository = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          expect(id, 'K260913000611');
          reads++;
          if (reads == 3) return late.future;
          return snapshot('peer-$reads');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FriendRequestsPage(
            realData: true,
            repository: repository,
            events: events.stream,
            onOpenAddFriend: () {},
            onOpenChat: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('peer-1'), findsOneWidget);
      events.add({'eventType': 'chat.friend-request.changed'});
      await tester.pumpAndSettle();
      expect(find.text('peer-1'), findsNothing);
      expect(find.text('peer-2'), findsOneWidget);
      await tester.tap(find.text('peer-2'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('friend-request-accept')),
        findsOneWidget,
      );
      events.add({'eventType': 'connection.ready'});
      await tester.pump();
      expect(reads, 3);
      SecureSessionStore.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('friend-request-accept')), findsNothing);
      late.complete(snapshot('late-peer'));
      await tester.pumpAndSettle();
      expect(find.text('peer-2'), findsNothing);
      expect(find.text('late-peer'), findsNothing);
      events.add({'eventType': 'connection.ready'});
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await events.close();
    },
  );
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
                'nickname': 'Actual Nickname',
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
      expect(find.text('Actual Nickname'), findsOneWidget);
      expect(find.text('actual-peer'), findsNothing);
      await tester.tap(find.text('Actual Nickname'));
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
