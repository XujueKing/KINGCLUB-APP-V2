import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_details_page.dart';
import 'package:kingclub/src/features/messaging/presentation/group_announcement_page.dart';

void main() {
  for (final announcement in [false, true]) {
    testWidgets(
      'group refresh retains network snapshot but clears denied: $announcement',
      (tester) async {
        final events = StreamController<Map<String, dynamic>>.broadcast();
        addTearDown(events.close);
        String? failure;
        final repo = GroupChatRepository(
          MessagingRepository(
            account: 'me',
            call: (id, _) async {
              if (id == 'K260913000619') {
                if (failure != null) {
                  throw AuthFailure(failure, 'internal detail');
                }
                return {
                  'groupId': 'group',
                  'groupName': 'Existing group',
                  'ownerAccount': 'me',
                  'metadataVersion': 1,
                  'membershipVersion': 1,
                  'announcementVersion': 1,
                  'announcementText': 'Existing notice',
                  'members': [
                    {
                      'account': 'me',
                      'nickname': 'Owner',
                      'role': 'owner',
                      'membershipVersion': 1,
                    },
                  ],
                };
              }
              if (id == 'K260913000621') {
                return {
                  'settings': {'muted': false, 'pinned': false},
                };
              }
              return {};
            },
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: announcement
                ? GroupAnnouncementPage(
                    groupId: 'group',
                    repository: repo,
                    events: events.stream,
                  )
                : GroupDetailsPage(
                    groupId: 'group',
                    repository: repo,
                    events: events.stream,
                  ),
          ),
        );
        await tester.pumpAndSettle();
        final label = announcement ? 'Existing notice' : 'Existing group';
        expect(find.text(label), findsOneWidget);
        for (final code in [
          'NETWORK_ERROR',
          null,
          'CHAT_GROUP_ACCESS_DENIED',
        ]) {
          failure = code;
          events.add({
            'eventType': 'chat.group.changed',
            'data': {'groupId': 'group'},
          });
          await tester.pumpAndSettle();
          expect(
            find.text(label),
            code == 'CHAT_GROUP_ACCESS_DENIED' ? findsNothing : findsOneWidget,
          );
          expect(find.text('internal detail'), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
