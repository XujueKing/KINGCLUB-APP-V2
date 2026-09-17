import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_details_page.dart';

void main() {
  testWidgets('200 members remain searchable without eager avatar requests', (
    tester,
  ) async {
    final events = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(events.close);
    final profiles = <String>[];
    var removed = false;
    final repo = GroupChatRepository(
      MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000619') {
            return {
              'groupName': 'Capacity fixture',
              'ownerAccount': 'owner',
              'metadataVersion': removed ? 2 : 1,
              'members': [
                for (var i = 0; i < (removed ? 199 : 200); i++)
                  {
                    'account': 'member-$i',
                    'nickname': 'Member $i',
                    'role': i == 0 ? 'owner' : 'member',
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
          if (id == 'K260913000612') {
            profiles.add(params['peer'] as String);
            return {'nickname': params['peer']};
          }
          throw StateError('Unexpected API $id');
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailsPage(
          groupId: 'group',
          repository: repo,
          events: events.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      profiles.length,
      lessThan(30),
      reason: 'offscreen members must not request all 200 profiles',
    );
    final search = find.byKey(const ValueKey('group-member-search'));
    await tester.scrollUntilVisible(
      search,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(search, 'member-199');
    await tester.pumpAndSettle();
    expect(find.text('Member 199'), findsOneWidget);
    expect(profiles, contains('member-199'));
    expect(profiles.length, lessThan(30));
    await tester.enterText(search, 'MEMBER 199');
    await tester.pumpAndSettle();
    expect(find.text('Member 199'), findsOneWidget);
    removed = true;
    events.add({
      'eventType': 'chat.group.changed',
      'data': {'groupId': 'group'},
    });
    await tester.pumpAndSettle();
    expect(find.text('Member 199'), findsNothing);
    expect(find.text('未找到群成员'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
