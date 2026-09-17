import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/foreground_group_call_inbox.dart';
import 'package:kingclub/src/features/messaging/data/group_call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

GroupCallSnapshot invited() => GroupCallSnapshot.parse({
  'callId': '00000000-0000-4000-8000-000000000001',
  'groupId': '00000000-0000-4000-8000-000000000001',
  'mediaKind': 'audio',
  'version': 1,
  'endedAtMs': null,
  'participants': [
    {'account': 'me', 'phase': 'invited', 'deadlineMs': 1000},
    {'account': 'friend', 'phase': 'joined', 'deadlineMs': 1000},
  ],
}, 'me');

class Repo extends GroupCallRepository {
  Repo(this.readCurrent)
    : super(
        MessagingRepository(
          account: 'me',
          call: (_, _) async => throw StateError('Unexpected action'),
        ),
      );
  final Future<GroupCallSnapshot?> Function() readCurrent;
  @override
  Future<GroupCallSnapshot?> current() => readCurrent();
}

void main() {
  for (final resumed in [false, true]) {
    testWidgets(
      'notification during lookup is replayed without waiting for timer resumed=$resumed',
      (tester) async {
        final first = Completer<GroupCallSnapshot?>();
        var reads = 0, shown = 0;
        Future<GroupCallSnapshot?> read() async =>
            ++reads == 1 ? first.future : invited();
        final inbox = ForegroundGroupCallInbox(
          repository: Repo(read),
          present: (_) async {
            shown++;
            return true;
          },
        );
        addTearDown(inbox.close);
        inbox.foreground(true);
        if (resumed) {
          inbox.foreground(false);
          inbox.foreground(true);
        } else {
          for (var n = 0; n < 10; n++) {
            inbox.notify();
          }
        }
        first.complete(null);
        await tester.pump();
        expect(reads, 2);
        expect(shown, 1);
        inbox.close();
      },
    );
  }
  test('repeated invitations present once without joining', () async {
    var shown = 0;
    final presentation = Completer<bool>();
    final inbox = ForegroundGroupCallInbox(
      repository: Repo(() async => invited()),
      present: (_) {
        shown++;
        return presentation.future;
      },
    );
    inbox.foreground(true);
    await Future<void>.delayed(Duration.zero);
    inbox.notify();
    inbox.notify();
    expect(shown, 1);
    presentation.complete(true);
    await inbox.refresh();
    await inbox.refresh();
    expect(shown, 1);
    inbox.close();
  });
  test('background transition drops a late invitation read', () async {
    final result = Completer<GroupCallSnapshot?>();
    var shown = 0;
    final inbox = ForegroundGroupCallInbox(
      repository: Repo(() => result.future),
      present: (_) async {
        shown++;
        return true;
      },
    );
    inbox.foreground(true);
    inbox.foreground(false);
    result.complete(invited());
    await Future<void>.delayed(Duration.zero);
    expect(shown, 0);
    inbox.close();
  });
}
