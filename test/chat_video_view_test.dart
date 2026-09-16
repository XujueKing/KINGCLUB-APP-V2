import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_video_view.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_cleanup.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';

class _NoLocalMedia extends MediaCache {
  @override
  Future<File> cached({
    required String scope,
    required String contentKey,
    required MediaKind kind,
  }) async => throw StateError('not cached');
}

void main() {
  for (final group in [false, true]) {
    testWidgets('deleted video ignores late grant and retry: group=$group', (
      tester,
    ) async {
      final pending = Completer<Map<String, dynamic>>();
      var requests = 0, downloads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatVideoView(
            repository: MessagingRepository(
              account: 'synthetic',
              call: (_, _) {
                requests++;
                return pending.future;
              },
            ),
            messageId: '12345678-1234-1234-1234-123456789012',
            group: group,
            full: true,
            mediaStore: _NoLocalMedia(),
            events: const Stream.empty(),
            loadFile: (_) async {
              downloads++;
              return File('unused');
            },
          ),
        ),
      );
      await tester.pump();
      expect(requests, 1);
      await ChatMediaDeletion(
        'synthetic',
        group,
        '12345678-1234-1234-1234-123456789012',
      ).dispatch();
      pending.complete({
        'messageId': '12345678-1234-1234-1234-123456789012',
        'video': {
          'path':
              '/kingclub/${group ? 'group-chat-video' : 'chat-video'}/12345678-1234-1234-1234-123456789012/video',
          'fileId': '12345678-1234-1234-1234-123456789012',
          'size': 3,
          'sha256': List.filled(64, '0').join(),
          'headers': {'authorization': 'Bearer fixture'},
        },
      });
      await tester.pumpAndSettle();
      expect(downloads, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('视频暂不可播放，点击重试'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(downloads, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final deleted in [false, true]) {
    testWidgets('saved video poster cleanup: explicit deletion=$deleted', (
      tester,
    ) async {
      late Directory directory;
      late MediaCache store;
      late File poster;
      late File video;
      final events = StreamController<Map<String, dynamic>>.broadcast();
      addTearDown(events.close);
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp(
          'kingclub-video-local-',
        );
        store = MediaCache(directory: () async => directory);
        poster = await store.importFile(
          File('assets/legacy/storage/wine_flip.png'),
          scope: 'member:synthetic',
          contentKey: 'chat-video-message:false:12345678-1234-1234-1234-123456789012:poster',
          kind: MediaKind.image,
        );
        video = await store.importFile(
          File('assets/legacy/storage/wine_flip.png'),
          scope: 'member:synthetic',
          contentKey: 'chat-video-message:false:12345678-1234-1234-1234-123456789012:video',
          kind: MediaKind.video,
        );
      });
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatVideoView(
            repository: MessagingRepository(
              account: 'synthetic',
              call: (_, _) async {
                calls++;
                throw const AuthFailure('ACCESS_DENIED', 'denied');
              },
            ),
            messageId: '12345678-1234-1234-1234-123456789012',
            mediaStore: store,
            events: events.stream,
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          FileImage(poster),
          tester.element(find.byType(ChatVideoView)),
        );
      });
      for (
        var attempt = 0;
        attempt < 20 && find.byType(Image).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(find.byType(Image), findsOneWidget);
      expect(calls, 0);
      if (deleted) {
        await tester.runAsync(
          () => ChatMediaCleanup(media: store).remove(
            account: 'synthetic',
            group: false,
            message: {
              'messageType': 'video',
              'messageId': '12345678-1234-1234-1234-123456789012',
            },
          ),
        );
      } else {
        events.add({'eventType': 'chat.relationship.changed'});
      }
      await tester.pump();
      for (var attempt = 0; attempt < 100; attempt++) {
        final remains = await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return await poster.exists() || await video.exists();
        });
        await tester.pump();
        if (remains == false) break;
      }
      await tester.runAsync(() async {
        expect(await poster.exists(), isFalse);
        expect(await video.exists(), isFalse);
      });
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(calls, deleted ? 0 : 1);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async => directory.delete(recursive: true));
    });
  }
  testWidgets(
    'denied video does not open a player and can retry authorization',
    (tester) async {
      var calls = 0;
      final repository = MessagingRepository(
        account: 'synthetic',
        call: (id, params) async {
          expect(id, 'K260915000668');
          calls++;
          throw StateError('denied');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatVideoView(
              repository: repository,
              messageId: '12345678-1234-1234-1234-123456789012',
              group: true,
              full: true,
              mediaStore: _NoLocalMedia(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('视频暂不可播放，点击重试'), findsOneWidget);
      expect(calls, 1);
      await tester.tap(find.text('视频暂不可播放，点击重试'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
