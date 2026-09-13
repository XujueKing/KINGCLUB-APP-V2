import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_member_avatar.dart';
import 'package:kingclub/src/core/media/cached_media_image.dart';

void main() {
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
