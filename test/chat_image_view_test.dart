import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/core/media/cached_media_image.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_image_view.dart';

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
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
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
      expect(view.contentKey, 'chat-image:me:file');
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
