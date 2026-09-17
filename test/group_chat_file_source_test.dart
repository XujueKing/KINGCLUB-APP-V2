import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_file_card.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_file_details_page.dart';
import 'package:kingclub/src/features/messaging/presentation/forward_text_page.dart';

import 'group_chat_controller_test.dart' show Queue, message, history;

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final mine in [false, true]) {
    for (final forward in [false, true]) {
      testWidgets('group file retains sender mine=$mine forward=$forward', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final sender = mine ? 'me' : 'other-member';
        final repository = MessagingRepository(
          account: 'me',
          call: (api, args) async {
            if (api == 'K260913000619') return {'members': []};
            if (api == 'K260913000621') {
              return history([
                {
                  ...message('file'),
                  'sender': sender,
                  'messageType': 'file',
                  'text': '[file]',
                  'fileName': 'sample.txt',
                  'fileSize': 321,
                  'fileAssetId': 'asset',
                  'fileSha256': 'a' * 64,
                },
              ]);
            }
            return {};
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: DirectChatPage(
              groupId: 'group',
              repository: repository,
              chatOutbox: Queue(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ChatFileCard), findsOneWidget);
        if (forward) {
          await tester.longPress(find.byType(ChatFileCard));
          await tester.pumpAndSettle();
          await tester.tap(find.text('转发'));
          await tester.pumpAndSettle();
          final page = tester.widget<ForwardTextPage>(
            find.byType(ForwardTextPage),
          );
          expect(page.file!.sender, sender);
          expect(page.file!.group, true);
          expect(page.file!.messageId, 'server-file');
        } else {
          await tester.tap(find.byType(ChatFileCard));
          await tester.pumpAndSettle();
          final page = tester.widget<ChatFileDetailsPage>(
            find.byType(ChatFileDetailsPage),
          );
          expect(page.reference.sender, sender);
          expect(page.reference.group, true);
          expect(page.reference.messageId, 'server-file');
          expect(page.repository, same(repository));
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
