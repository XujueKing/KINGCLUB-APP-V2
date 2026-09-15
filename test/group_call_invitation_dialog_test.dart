import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/group_call_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_call_invitation_dialog.dart';

void main() {
  for (final change in ['session', 'expiry', 'ended']) {
    testWidgets('invitation closes on $change without accepting', (
      tester,
    ) async {
      final sessions = StreamController<void>.broadcast(sync: true);
      final deadline = DateTime.now().millisecondsSinceEpoch + 1000;
      Map<String, dynamic> state(bool ended) => {
        'callId': '00000000-0000-4000-8000-000000000001',
        'groupId': '00000000-0000-4000-8000-000000000001',
        'version': 1,
        'mediaKind': 'audio',
        'endedAtMs': ended ? 1 : null,
        'participants': [
          {
            'account': 'me',
            'phase': ended ? 'expired' : 'invited',
            'deadlineMs': deadline,
          },
          {
            'account': 'friend',
            'phase': ended ? 'left' : 'joined',
            'deadlineMs': deadline,
          },
        ],
      };
      final controller = GroupCallController(
        repository: GroupCallRepository(
          MessagingRepository(
            account: 'me',
            call: (id, _) async {
              expect(id, 'K260915000680');
              return state(change == 'ended');
            },
          ),
        ),
        initial: GroupCallSnapshot.parse(state(false), 'me'),
        sessionChanges: sessions.stream,
        invalidations: const Stream.empty(),
      );
      bool? answer;
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                answer = await showDialog<bool>(
                  context: context,
                  builder: (_) =>
                      GroupCallInvitationDialog(controller: controller),
                );
                completed = true;
              },
              child: const Text('show'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('show'));
      await tester.pump();
      if (change == 'session') sessions.add(null);
      if (change == 'expiry') await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(completed, true);
      expect(answer, null);
      expect(find.text('接听'), findsNothing);
      unawaited(sessions.close());
      await tester.pumpWidget(const SizedBox());
    });
  }
}
