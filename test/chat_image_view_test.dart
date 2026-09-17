import 'dart:async';
import 'dart:io';

import 'package:kingclub/src/core/media/media_cache.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/core/media/cached_media_image.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_image_view.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

Map<String, dynamic> grant({
  String path = '/kingclub/chat-image/m/thumbnail',
}) => {
  'messageId': 'm',
  'thumbnail': {
    'path': path,
    'fileId': 'file',
    'width': 160,
    'height': 100,
    'headers': {'authorization': 'Bearer fixture'},
  },
};

class EmptyMedia extends MediaCache {
  @override
  Future<File> cachedImage({
    required String scope,
    required String contentKey,
  }) async => throw StateError('not downloaded');
}

void main() {
  for (final result in ['allowed', 'offline', 'denied']) {
    testWidgets('local image stays stable during reconnect: $result', (
      tester,
    ) async {
      late Directory root;
      late MediaCache store;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('image-reconnect-');
        store = MediaCache(directory: () async => root);
        await store.importBytes(
          await File('assets/legacy/storage/wine_flip.png').readAsBytes(),
          scope: 'member:me',
          contentKey: 'chat-image-message:false:m:thumbnail',
          kind: MediaKind.image,
        );
      });
      final events = StreamController<Map<String, dynamic>>();
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatImageView(
            repository: MessagingRepository(
              account: 'me',
              call: (_, _) async {
                calls++;
                return pending.future;
              },
            ),
            messageId: 'm',
            mediaStore: store,
            events: events.stream,
          ),
        ),
      );
      await tester.runAsync(() async {
        for (var i = 0; i < 50 && find.byType(Image).evaluate().isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      expect(find.byType(Image), findsOneWidget);
      final original = tester.element(find.byType(Image));
      final size = tester.getSize(find.byType(Image));
      await tester.runAsync(
        () => precacheImage(
          tester.widget<Image>(find.byType(Image)).image,
          tester.element(find.byType(Image)),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.element(find.byType(Image)), same(original));
      // Let the lifecycle-triggered filesystem read finish before disposal;
      // its stale result must not replace the later authorization result.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      events.add({'eventType': 'connection.ready'});
      await tester.pump();
      expect(calls, 1);
      expect(tester.element(find.byType(Image)), same(original));
      expect(tester.getSize(find.byType(Image)), size);
      if (result == 'allowed') {
        pending.complete(grant());
      } else {
        pending.completeError(
          AuthFailure(
            result == 'offline' ? 'NETWORK_ERROR' : 'CHAT_ACCESS_DENIED',
            'fixture',
          ),
        );
      }
      await tester.pump();
      if (result == 'denied') {
        expect(find.byType(Image), findsNothing);
      } else {
        expect(tester.element(find.byType(Image)), same(original));
        expect(tester.getSize(find.byType(Image)), size);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await events.close();
        await root.delete(recursive: true);
      });
    });
  }
  for (final mode in [
    'downloaded',
    'original-thumbnail',
    'sent-thumbnail',
    'sent-full',
  ]) {
    testWidgets('$mode image reopens offline from real local storage', (
      tester,
    ) async {
      late Directory root;
      late MediaCache media;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('chat-image-local-');
        final source = File('assets/legacy/storage/wine_flip.png');
        media = MediaCache(
          directory: () async => Directory('${root.path}/media'),
        );
        await media.importBytes(
          await source.readAsBytes(),
          scope: 'member:me',
          contentKey: mode == 'original-thumbnail'
              ? 'chat-image-message:false:m:image'
              : mode == 'downloaded'
              ? 'chat-image-message:false:m:thumbnail'
              : 'chat-image-sent:local-id',
          kind: MediaKind.image,
        );
        media = MediaCache(
          directory: () async => Directory('${root.path}/media'),
        );
      });
      var requests = 0;
      final repo = MessagingRepository(
        account: 'me',
        call: (_, _) async {
          requests++;
          throw StateError('offline');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatImageView(
            repository: repo,
            messageId: 'm',
            mediaStore: media,
            sentClientMessageId:
                mode == 'downloaded' || mode == 'original-thumbnail'
                ? null
                : 'local-id',
            full: mode == 'sent-full',
            events: const Stream.empty(),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (var i = 0; i < 50 && find.byType(Image).evaluate().isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      await tester.pump();
      expect(requests, 0);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.widget<Image>(find.byType(Image)).image, isA<FileImage>());
      await tester.runAsync(
        () => precacheImage(
          tester.widget<Image>(find.byType(Image)).image,
          tester.element(find.byType(Image)),
        ),
      );
      for (final event in [
        const ChatMediaDeletion('other', false, 'm'),
        const ChatMediaDeletion('me', true, 'm'),
        const ChatMediaDeletion('me', false, 'other'),
      ]) {
        await event.dispatch();
      }
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      await const ChatMediaDeletion('me', false, 'm').dispatch();
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => root.delete(recursive: true));
    });
  }
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final group in [false, true]) {
    testWidgets('image ignores unrelated scopes; group=$group', (tester) async {
      final events = StreamController<Map<String, dynamic>>();
      var calls = 0;
      final repository = MessagingRepository(
        account: 'me',
        call: (_, _) async {
          calls++;
          return grant(
            path:
                '/kingclub/${group ? 'group-chat-image' : 'chat-image'}/m/thumbnail',
          );
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatImageView(
            mediaStore: EmptyMedia(),
            repository: repository,
            messageId: 'm',
            group: group,
            scopeId: 'current',
            events: events.stream,
          ),
        ),
      );
      await tester.pump();
      for (final type in ['chat.group.read', 'chat.group.changed']) {
        events.add({
          'eventType': type,
          'data': {'groupId': 'other'},
        });
      }
      events.add({
        'eventType': 'chat.settings.changed',
        'data': {'conversationId': 'other'},
      });
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(CachedMediaImage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      unawaited(events.close());
    });
  }
  testWidgets('group read rechecks without flashing; denial removes image', (
    tester,
  ) async {
    final events = StreamController<Map<String, dynamic>>();
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    final repository = MessagingRepository(
      account: 'me',
      call: (_, _) async {
        if (++calls > 1) return pending.future;
        return grant(path: '/kingclub/group-chat-image/m/thumbnail');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatImageView(
          mediaStore: EmptyMedia(),
          repository: repository,
          messageId: 'm',
          group: true,
          scopeId: 'current',
          events: events.stream,
        ),
      ),
    );
    await tester.pump();
    events.add({
      'eventType': 'chat.group.read',
      'data': {'groupId': 'current'},
    });
    await tester.pump();
    expect(calls, 2);
    expect(find.byType(CachedMediaImage), findsOneWidget);
    pending.completeError(StateError('removed'));
    await tester.pumpAndSettle();
    expect(find.byType(CachedMediaImage), findsNothing);
    await tester.pumpWidget(const SizedBox());
    unawaited(events.close());
  });
  testWidgets('external media path never constructs a credentialed image', (
    tester,
  ) async {
    final repository = MessagingRepository(
      account: 'me',
      call: (id, input) async {
        expect(id, 'K260913000633');
        expect(input['messageId'], 'm');
        return grant(path: 'https://foreign.invalid/image');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatImageView(
          mediaStore: EmptyMedia(),
          repository: repository,
          messageId: 'm',
          events: const Stream.empty(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CachedMediaImage), findsNothing);
    expect(find.text('图片暂不可查看'), findsOneWidget);
  });
  testWidgets('session change discards late media authorization', (
    tester,
  ) async {
    final response = Completer<Map<String, dynamic>>();
    final repository = MessagingRepository(
      account: 'me',
      call: (_, _) => response.future,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatImageView(
          mediaStore: EmptyMedia(),
          repository: repository,
          messageId: 'm',
          events: const Stream.empty(),
        ),
      ),
    );
    SecureSessionStore.changes.add(null);
    await tester.pump();
    response.complete(grant());
    await tester.pump();
    expect(find.byType(CachedMediaImage), findsNothing);
    expect(find.text('图片暂不可查看'), findsOneWidget);
  });
  testWidgets(
    'relationship invalidation clears old authorization and ignores its late response',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>();
      final first = Completer<Map<String, dynamic>>();
      final second = Completer<Map<String, dynamic>>();
      var calls = 0;
      final repository = MessagingRepository(
        account: 'me',
        call: (_, _) => ++calls == 1 ? first.future : second.future,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatImageView(
            mediaStore: EmptyMedia(),
            repository: repository,
            messageId: 'm',
            events: events.stream,
          ),
        ),
      );
      events.add({'eventType': 'chat.relationship.changed'});
      await tester.pump();
      expect(calls, 2);
      first.complete(grant());
      await tester.pump();
      expect(find.byType(CachedMediaImage), findsNothing);
      second.completeError(StateError('blocked'));
      await tester.pumpAndSettle();
      expect(find.text('图片暂不可查看'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      unawaited(events.close());
    },
  );
  testWidgets(
    'authorized thumbnail uses private cache and is removed on session change',
    (tester) async {
      final repository = MessagingRepository(
        account: 'me',
        call: (_, _) async => grant(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatImageView(
            mediaStore: EmptyMedia(),
            repository: repository,
            messageId: 'm',
            events: const Stream.empty(),
          ),
        ),
      );
      await tester.pump();
      final view = tester.widget<CachedMediaImage>(
        find.byType(CachedMediaImage),
      );
      expect(view.private, true);
      expect(view.contentKey, 'chat-image-message:false:m:thumbnail');
      expect(view.headers, {'authorization': 'Bearer fixture'});
      SecureSessionStore.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.byType(CachedMediaImage), findsNothing);
    },
  );
  testWidgets(
    'group images use group authorization and clear on membership change',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>();
      var allowed = true;
      final repository = MessagingRepository(
        account: 'me',
        call: (id, _) async {
          expect(id, 'K260913000635');
          if (!allowed) throw StateError('removed');
          return grant(path: '/kingclub/group-chat-image/m/thumbnail');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatImageView(
            mediaStore: EmptyMedia(),
            repository: repository,
            messageId: 'm',
            group: true,
            events: events.stream,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CachedMediaImage), findsOneWidget);
      allowed = false;
      events.add({'eventType': 'chat.group.changed'});
      await tester.pumpAndSettle();
      expect(find.byType(CachedMediaImage), findsNothing);
      expect(find.text('图片暂不可查看'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      unawaited(events.close());
    },
  );
}
