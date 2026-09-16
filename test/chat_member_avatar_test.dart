import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_member_avatar.dart';
import 'package:kingclub/src/core/media/cached_media_image.dart';
import 'package:kingclub/src/features/messaging/data/chat_avatar_snapshot.dart';

class _LocalAvatar extends ChatAvatarSnapshot {
  @override
  Future<Map<String, dynamic>?> readCached(String peer) async => {
    'avatar': {'fileId': 'saved-avatar', 'cacheOnly': true},
  };
}

void main() {
  testWidgets(
    'saved avatar displays before slow profile and is removed on denial',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatMemberAvatar(
            account: 'peer',
            profile: pending.future,
            snapshots: _LocalAvatar(),
            baseUrl: 'https://test.wuyexin.cn/kingclub-v2',
          ),
        ),
      );
      await tester.pump();
      final image = tester.widget<CachedMediaImage>(
        find.byType(CachedMediaImage),
      );
      expect(image.cacheOnly, isTrue);
      expect(image.contentKey, 'profile:peer:saved-avatar');
      pending.completeError(StateError('denied'));
      await tester.pumpAndSettle();
      expect(find.byType(CachedMediaImage), findsNothing);
    },
  );
  Widget view(Future<Map<String, dynamic>> profile) => MaterialApp(
    home: Scaffold(
      body: ChatMemberAvatar(profile: profile, account: 'peer'),
    ),
  );
  testWidgets(
    'loading and denied profiles show neutral avatar without spinner',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(view(pending.future));
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.getSize(find.byType(ChatMemberAvatar)), const Size(42, 42));
      pending.completeError(StateError('denied'));
      await tester.pump();
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byType(CachedMediaImage), findsNothing);
    },
  );
  for (final own in [false, true]) {
    testWidgets(
      'authorized ${own ? "owner" : "visitor"} descriptor uses private cache and drops stale image',
      (tester) async {
        final initial = Future<Map<String, dynamic>>.value({
          'avatar': {
            'fileId': 'fixture-file',
            'path': own
                ? '/attachments/fixture-file?token=fixture.token'
                : '/kingclub/profile-media/fixture-file',
            'headers': own
                ? <String, String>{}
                : {'x-profile-media-token': 'fixture'},
          },
        });
        Widget frame(Future<Map<String, dynamic>> profile) => MaterialApp(
          home: Scaffold(
            body: ChatMemberAvatar(
              account: 'peer',
              baseUrl: 'https://test.wuyexin.cn/kingclub-v2',
              own: own,
              profile: profile,
            ),
          ),
        );
        await tester.pumpWidget(frame(initial));
        await tester.pump();
        final image = tester.widget<CachedMediaImage>(
          find.byType(CachedMediaImage),
        );
        expect(image.private, true);
        expect(image.contentKey, 'profile:peer:fixture-file');
        expect(image.url, startsWith('https://test.wuyexin.cn/kingclub-v2/'));
        final refresh = Completer<Map<String, dynamic>>();
        await tester.pumpWidget(frame(refresh.future));
        expect(find.byType(CachedMediaImage), findsNothing);
        refresh.completeError(StateError('permission changed'));
        await tester.pump();
        expect(find.byIcon(Icons.person), findsOneWidget);
      },
    );
  }
  testWidgets('foreign avatar URL cannot receive private headers', (
    tester,
  ) async {
    await tester.pumpWidget(
      view(
        Future.value({
          'avatar': {
            'fileId': 'file',
            'path': 'https://example.invalid/avatar',
            'headers': {'authorization': 'fixture'},
          },
        }),
      ),
    );
    await tester.pump();
    expect(find.byType(CachedMediaImage), findsNothing);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
