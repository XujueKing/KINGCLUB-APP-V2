import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_video_view.dart';
import 'package:kingclub/src/core/media/media_cache.dart';

class _NoLocalMedia extends MediaCache {
  @override
  Future<File> cached({
    required String scope,
    required String contentKey,
    required MediaKind kind,
  }) async => throw StateError('not cached');
}

void main() {
  testWidgets('saved video poster opens offline without media grant', (
    tester,
  ) async {
    late Directory directory;
    late MediaCache store;
    late File poster;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp(
        'kingclub-video-local-',
      );
      store = MediaCache(directory: () async => directory);
      poster = await store.importFile(
        File('assets/legacy/storage/wine_flip.png'),
        scope: 'member:synthetic',
        contentKey: 'chat-video-message:false:message:poster',
        kind: MediaKind.image,
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
              throw StateError('offline');
            },
          ),
          messageId: 'message',
          mediaStore: store,
          events: const Stream.empty(),
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
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async => directory.delete(recursive: true));
  });
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
