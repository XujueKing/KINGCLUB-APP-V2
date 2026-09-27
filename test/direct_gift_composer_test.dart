import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, history;

void main() {
  testWidgets(
    'real gifts use catalog pricing, require confirmation and render the receipt',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      FlutterSecureStorage.setMockInitialValues({});
      final sends = <Map<String, dynamic>>[];
      final repo = MessagingRepository(
        account: 'me',
        call: (method, params) async {
          if (method == 'K260913000604') return history([]);
          if (method == 'K260927000802') {
            return {
              'gifts': [
                {
                  'giftId': 'rose',
                  'name': '目录玫瑰',
                  'assetKey': 'rose',
                  'unitPrice': '51',
                },
              ],
            };
          }
          if (method == 'K260927000803') {
            sends.add(params);
            const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
            return {
              'message': {
                'messageId': id,
                'clientMessageId': params['clientMessageId'],
                'conversationId': 'c',
                'sequence': 1,
                'sender': 'me',
                'recipient': 'peer',
                'messageType': 'gift',
                'text': '[礼物]',
                'gift': {
                  'transferId': id,
                  'giftId': 'rose',
                  'name': '目录玫瑰',
                  'assetKey': 'rose',
                  'unitPrice': '51',
                  'quantity': 2,
                  'total': '102',
                },
              },
            };
          }
          return {};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DirectChatPage(
            peerAccount: 'peer',
            peerName: '测试好友',
            repository: repo,
            chatOutbox: MemoryOutbox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('direct-chat-attachments')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('礼物'));
      await tester.pumpAndSettle();
      expect(find.text('51 金币'), findsOneWidget);
      expect(find.text('501'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('direct-chat-gift-rose')));
      await tester.pumpAndSettle();
      expect(sends, isEmpty);
      expect(find.text('赠送给 测试好友'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(sends, isEmpty);
      await tester.tap(find.byKey(const ValueKey('direct-chat-gift-rose')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '2',
      );
      await tester.pump();
      expect(find.text('合计 102 金币'), findsOneWidget);
      await tester.tap(find.text('确认赠送'));
      await tester.pumpAndSettle();
      expect(sends, hasLength(1));
      expect(sends.single['quantity'], 2);
      expect(sends.single['expectedUnitPrice'], '51');
      expect(find.text('目录玫瑰 × 2\n102 金币'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('direct-chat-gift-message')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
