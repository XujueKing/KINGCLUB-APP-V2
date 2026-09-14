import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_member_avatar.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_details_page.dart';
import 'package:kingclub/src/features/messaging/presentation/legacy_messaging_components.dart';

void main() {
  testWidgets(
    'real details reuse authorized profile on rebuild and tolerate denial',
    (tester) async {
      final profile = Completer<Map<String, dynamic>>();
      var reads = 0;
      final repository = MessagingRepository(
        account: 'me',
        call: (id, params) {
          if (id == 'K260913000612') {
            expect(params, {'peer': 'peer'});
            reads++;
            return profile.future;
          }
          return Future.value({});
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DirectChatDetailsPage(
            peerName: 'Friend',
            peerAccount: 'peer',
            repository: repository,
          ),
        ),
      );
      expect(reads, 1);
      expect(find.byType(LegacyFakeAvatar), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.getSize(find.byType(ChatMemberAvatar)), const Size(52, 52));
      await tester.tap(find.byKey(const ValueKey('direct-chat-details-muted')));
      await tester.pumpAndSettle();
      expect(reads, 1);
      profile.completeError(StateError('denied'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
