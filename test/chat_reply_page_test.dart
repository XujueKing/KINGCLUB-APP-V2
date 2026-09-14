import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, ack, history;

void main() {
  testWidgets(
    'quote selection, cancel and send retain the chosen source only',
    (tester) async {
      tester.view.physicalSize = const Size(393, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FlutterSecureStorage.setMockInitialValues({});
      const source = '11111111-1111-4111-8111-111111111111';
      final sent = <Map<String, dynamic>>[];
      final queue = MemoryOutbox();
      final repo = MessagingRepository(
        account: 'me',
        call: (id, p) async {
          if (id == 'K260913000604') {
            return {
              ...history([
                {
                  ...ack({
                    'clientMessageId': 'source',
                    'text': 'Original message',
                  }),
                  'messageId': source,
                },
              ]),
              'canReply': true,
            };
          }
          if (id == 'K260913000601') {
            sent.add({...p});
            throw const AuthFailure('NETWORK_ERROR', 'offline');
          }
          return {};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DirectChatPage(
            peerAccount: 'peer',
            repository: repo,
            chatOutbox: queue,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> selectQuote() async {
        await tester.longPress(find.text('Original message'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('引用'));
        await tester.pumpAndSettle();
      }

      await selectQuote();
      expect(
        find.byKey(const ValueKey('direct-chat-close-quote')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('direct-chat-close-quote')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('direct-chat-close-quote')),
        findsNothing,
      );
      await selectQuote();
      await tester.enterText(
        find.byKey(const ValueKey('direct-chat-input')),
        'Reply text',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('direct-chat-send')));
      await tester.pumpAndSettle();
      expect(sent.single['replyToMessageId'], source);
      expect(queue.items.values.single['replyToMessageId'], source);
      expect(
        find.byKey(const ValueKey('direct-chat-close-quote')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('direct-chat-input')),
        'Plain text',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('direct-chat-send')));
      await tester.pumpAndSettle();
      expect(sent.last.containsKey('replyToMessageId'), false);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
