import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_details_page.dart';

void main() {
  for (final mode in ['success', 'failure', 'cancel', 'session']) {
    testWidgets('group history clear $mode', (tester) async {
      var writes = 0, cleanups = 0;
      bool? departed;
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, params) async {
            if (id == 'K260913000619') {
              return {
                'groupName': 'fixture',
                'ownerAccount': 'owner',
                'metadataVersion': 1,
                'members': [
                  {
                    'account': 'me',
                    'nickname': 'Me',
                    'role': 'member',
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
            if (id == 'K260913000612') return {'nickname': 'Me'};
            if (id == 'K260913000623') {
              expect(params, {'groupId': 'group', 'hide': true});
              writes++;
              return {'saved': mode != 'failure'};
            }
            fail('Unexpected operation: $id');
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  departed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => GroupDetailsPage(
                        groupId: 'group',
                        repository: repo,
                        onHistoryCleared: () => cleanups++,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final clear = find.byKey(const ValueKey('group-clear-history'));
      await tester.ensureVisible(clear);
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pumpAndSettle();
      if (mode == 'session') {
        SecureSessionStore.changes.add(null);
        await tester.pumpAndSettle();
      }
      await tester.tap(
        mode == 'cancel'
            ? find.text('取消')
            : find.byKey(const ValueKey('group-confirm-clear-history')),
      );
      await tester.pumpAndSettle();
      expect(writes, ['success', 'failure'].contains(mode) ? 1 : 0);
      expect(cleanups, mode == 'success' ? 1 : 0);
      if (mode == 'success') {
        expect(departed, isFalse);
        expect(find.text('open'), findsOneWidget);
      } else {
        expect(departed, isNull);
        expect(find.byType(GroupDetailsPage), findsOneWidget);
      }
    });
  }
}
