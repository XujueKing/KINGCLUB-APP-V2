import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/cached_media_image.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/contacts/presentation/friendship_pages.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

Map<String, dynamic> row(String name) => {
  'requestId': name,
  'requester': name,
  'recipient': 'me',
  'nickname': name,
  'requestStatus': 'pending',
};

class _History implements ChatHistoryStore {
  final cacheRead = Completer<List<Map<String, dynamic>>?>();
  List<Map<String, dynamic>>? saved;
  @override
  String get account => 'me';
  @override
  Future<List<Map<String, dynamic>>?> friendRequestSnapshot() =>
      cacheRead.future;
  @override
  Future<void> saveFriendRequestSnapshot(
    List<Map<String, dynamic>> rows,
    int started,
  ) async {
    saved = rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final mode in ['offline', 'network-first', 'logout', 'auth-failure']) {
    testWidgets('request cache $mode retains correct generation', (
      tester,
    ) async {
      final history = _History();
      final response = Completer<Map<String, dynamic>>();
      final repository = MessagingRepository(
        account: 'me',
        call: (_, _) => response.future,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FriendRequestsPage(
            realData: true,
            repository: repository,
            openHistory: (_) async => history,
            events: const Stream.empty(),
            onOpenAddFriend: () {},
            onOpenChat: (_) {},
          ),
        ),
      );
      await tester.pump();
      if (mode == 'offline') {
        response.completeError(const AuthFailure('NETWORK_ERROR', 'offline'));
        await tester.pumpAndSettle();
        history.cacheRead.complete([
          {
            ...row('Cached Friend'),
            'avatar': {'fileId': 'avatar-1', 'cacheOnly': true},
          },
        ]);
        await tester.pumpAndSettle();
        expect(find.text('Cached Friend'), findsOneWidget);
        final avatar = tester.widget<CachedMediaImage>(
          find.byType(CachedMediaImage),
        );
        expect(avatar.cacheOnly, isTrue);
        expect(avatar.url, isEmpty);
        expect(avatar.headers, isEmpty);
        await tester.tap(find.text('Cached Friend'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('friend-request-accept')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('friend-requests-partial-error')),
          findsNothing,
        );
        expect(history.saved, isNull);
      } else {
        if (mode == 'network-first') {
          response.complete({
            'items': [row('Current Friend')],
            'hasMore': false,
          });
        } else if (mode == 'auth-failure') {
          response.completeError(
            const AuthFailure('SESSION_EXPIRED', 'expired'),
          );
        } else {
          SecureSessionStore.changes.add(null);
          await tester.pump();
          response.complete({
            'items': [row('Current Friend')],
            'hasMore': false,
          });
        }
        await tester.pumpAndSettle();
        history.cacheRead.complete([row('Cached Friend')]);
        await tester.pumpAndSettle();
        expect(find.text('Cached Friend'), findsNothing);
        expect(
          find.text('Current Friend'),
          mode == 'network-first' ? findsOneWidget : findsNothing,
        );
        if (mode == 'network-first') {
          expect(history.saved!.single['nickname'], 'Current Friend');
        } else {
          expect(history.saved, isNull);
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
