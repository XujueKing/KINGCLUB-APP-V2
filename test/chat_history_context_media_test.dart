import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_history_context_page.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_file_details_page.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_location_message.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_image_view.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_video_view.dart';

void main() {
  for (final type in ['image', 'video']) {
    for (final mine in [false, true]) {
      testWidgets('context $type keeps sender cache identity mine=$mine', (
        tester,
      ) async {
        final repository = MessagingRepository(
          account: 'me',
          call: (_, _) async => throw StateError('offline'),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ChatHistoryContextPage(
              account: 'me',
              messageId: 'media',
              sequence: 1,
              repository: repository,
              events: const Stream.empty(),
              read: ({before, after, required limit}) async => {
                'messages': before == null
                    ? []
                    : [
                        {
                          'messageId': 'media',
                          'sequence': 1,
                          'sender': mine ? 'me' : 'friend',
                          'clientMessageId': 'client',
                          'messageType': type,
                          'text': '[media]',
                        },
                      ],
                'settings': {'hiddenThrough': 0},
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (type == 'image') {
          expect(
            tester
                .widget<ChatImageView>(find.byType(ChatImageView))
                .sentClientMessageId,
            mine ? 'client' : null,
          );
          await tester.tap(find.byKey(const ValueKey('context-image-media')));
        } else {
          final video = tester.widget<ChatVideoView>(
            find.byType(ChatVideoView),
          );
          expect(video.sentClientMessageId, mine ? 'client' : null);
          video.onTap!();
        }
        // Only finish navigation: this wiring test supplies no video decoder
        // or local file, so a loading spinner need not become idle.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        if (type == 'image') {
          final full = tester.widget<ChatImageView>(find.byType(ChatImageView));
          expect(full.full, true);
          expect(full.sentClientMessageId, mine ? 'client' : null);
        } else {
          final full = tester.widget<ChatVideoView>(find.byType(ChatVideoView));
          expect(full.full, true);
          expect(full.sentClientMessageId, mine ? 'client' : null);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
    'history renders actionable media and keeps group file authorization scope',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MessagingRepository(
        account: 'me',
        call: (_, _) async => throw StateError('not downloaded in this test'),
      );
      final rows = [
        {
          'messageId': 'voice',
          'sequence': 1,
          'sender': 'friend',
          'messageType': 'voice',
          'text': '[语音]',
          'voiceDurationMs': 3000,
        },
        {
          'messageId': 'file',
          'sequence': 2,
          'sender': 'me',
          'messageType': 'file',
          'text': '[文件]',
          'fileName': 'sample.txt',
          'fileSize': 321,
          'fileAssetId': 'asset',
          'fileSha256': 'digest',
        },
        {
          'messageId': 'location',
          'sequence': 3,
          'sender': 'friend',
          'messageType': 'location',
          'text': '[位置]',
          'location': {
            'latitudeE6': 31000000,
            'longitudeE6': 121000000,
            'coordinateSystem': 'wgs84',
            'name': '测试地点',
            'address': '测试地址',
          },
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: ChatHistoryContextPage(
            account: 'me',
            repository: repository,
            groupId: 'test-group',
            messageId: 'file',
            sequence: 2,
            senderLabel: (account) => account == 'me' ? '我' : '朋友',
            read: ({before, after, required limit}) async => {
              'messages': rows
                  .where(
                    (row) => before != null
                        ? (row['sequence'] as int) < before
                        : (row['sequence'] as int) > after!,
                  )
                  .toList(),
              'settings': {'hiddenThrough': 0},
              'membershipVersion': 1,
              'joinedSequence': 0,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('播放语音 3秒'), findsOneWidget);
      expect(find.byType(ChatLocationMessage), findsOneWidget);
      await tester.tap(find.text('sample.txt'));
      await tester.pumpAndSettle();
      final details = tester.widget<ChatFileDetailsPage>(
        find.byType(ChatFileDetailsPage),
      );
      expect(details.reference.messageId, 'file');
      expect(details.reference.group, isTrue);
      expect(identical(details.repository, repository), isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
