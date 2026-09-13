import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';
import 'package:kingclub/src/features/messaging/presentation/call_page.dart';

void main() {
  testWidgets(
    'dial entry suppresses repeats, retries the same request and discards a late result after leaving',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var pending = Completer<Map<String, dynamic>>();
      final requests = <String>[];
      var relayReads = 0;
      final repo = MessagingRepository(
        account: 'me',
        call: (method, params) async {
          if (method == 'K260913000643') {
            requests.add(params['requestId'] as String);
            expect(params['peer'], 'friend');
            expect(params['mediaKind'], 'video');
            return pending.future;
          }
          if (method == 'K260914000648') relayReads++;
          if (method == 'K260913000604')
            return {
              'conversationId': 'pair',
              'messages': [],
              'hasMore': false,
              'settings': {},
              'sendPermission': {'allowed': true},
              'peerReadSequence': 0,
            };
          return {};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DirectChatPage(peerAccount: 'friend', repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> dial() async {
        await tester.tap(find.byKey(const ValueKey('direct-chat-attachments')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('视频通话'));
        await tester.pumpAndSettle();
      }

      await dial();
      expect(requests, hasLength(1));
      await dial();
      expect(requests, hasLength(1));
      pending.completeError(Exception('lost acknowledgement'));
      await tester.pumpAndSettle();
      pending = Completer<Map<String, dynamic>>();
      // The ignored repeat left the panel open.
      await tester.tap(find.text('视频通话'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests[0], requests[1]);
      await tester.pumpWidget(const SizedBox());
      pending.complete({
        'callId': '00000000-0000-4000-8000-000000000001',
        'caller': 'me',
        'callee': 'friend',
        'mediaKind': 'video',
        'phase': 'ringing',
        'version': 0,
        'deadlineMs': 9999999999999,
      });
      await tester.pumpAndSettle();
      expect(relayReads, 0);
      expect(find.byType(CallPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
