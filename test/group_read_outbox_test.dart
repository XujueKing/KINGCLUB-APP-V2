import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_read_outbox.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox_recovery.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'denied reads cool down without delaying healthy or newer reads',
    () async {
      var now = DateTime.utc(2026, 9, 16);
      final group = ChatReadOutbox('me', group: true);
      final direct = ChatReadOutbox('me');
      await group.put('same', 5);
      final calls = <String>[];
      var denied = true;
      final repo = MessagingRepository(
        account: 'me',
        readOutbox: direct,
        groupReadOutbox: group,
        readRetryClock: () => now,
        call: (method, params) async {
          calls.add('$method:${params['sequence']}');
          if (method == 'K260913000622' && denied) {
            throw const AuthFailure('CHAT_GROUP_ACCESS_DENIED', 'not a member');
          }
          return {};
        },
      );
      await repo.retryPendingReads(isActive: () => true);
      expect(calls, ['K260913000622:5']);
      now = now.add(const Duration(seconds: 15));
      await direct.put('same', 5);
      await repo.retryPendingReads(isActive: () => true);
      expect(calls, ['K260913000622:5', 'K260913000605:5']);
      expect(await group.read(), {'same': 5});

      // A newer read watermark bypasses the previous rejection's cooldown.
      await group.put('same', 6);
      await repo.retryPendingReads(isActive: () => true);
      expect(calls.last, 'K260913000622:6');
      expect(calls.length, 3);
      now = now.add(const Duration(minutes: 4, seconds: 59));
      await repo.retryPendingReads(isActive: () => true);
      expect(calls.length, 3);
      now = now.add(const Duration(seconds: 1));
      denied = false;
      await repo.retryPendingReads(isActive: () => true);
      expect(calls.length, 4);
      expect(await group.read(), isEmpty);

      // Explicit reading can retry immediately after permissions are restored.
      denied = true;
      await group.put('same', 7);
      await repo.retryPendingReads(isActive: () => true);
      denied = false;
      await repo.markGroupRead('same', 7);
      expect(calls.length, 6);
      expect(await group.read(), isEmpty);
    },
  );

  test(
    'group offline read survives restart and cannot overwrite direct read',
    () async {
      final direct = ChatReadOutbox('me');
      await direct.put('same-id', 3);
      final group = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          groupReadOutbox: ChatReadOutbox('me', group: true),
          call: (_, _) async =>
              throw const AuthFailure('NETWORK_ERROR', 'offline'),
        ),
      );
      await expectLater(
        group.markRead('same-id', 8),
        throwsA(isA<AuthFailure>()),
      );
      expect(await direct.read(), {'same-id': 3});
      final reopened = ChatReadOutbox('me', group: true);
      expect(await reopened.read(), {'same-id': 8});
      final calls = <String>[];
      final worker = ChatOutboxRecovery(
        MessagingRepository(
          account: 'me',
          readOutbox: direct,
          groupReadOutbox: reopened,
          call: (method, params) async {
            calls.add(method);
            if (method == 'K260913000605') {
              expect(params, {'peer': 'same-id', 'sequence': 3});
            } else {
              expect(params, {'groupId': 'same-id', 'sequence': 8});
            }
            return {};
          },
        ),
        MemoryOutbox(),
      );
      await worker.notify();
      expect(calls, ['K260913000605', 'K260913000622']);
      expect(await direct.read(), isEmpty);
      expect(await reopened.read(), isEmpty);
      worker.close();
    },
  );

  test('late group read acknowledgement preserves a newer watermark', () async {
    final queue = ChatReadOutbox('me', group: true);
    final response = Completer<Map<String, dynamic>>();
    final called = Completer<void>();
    final group = GroupChatRepository(
      MessagingRepository(
        account: 'me',
        groupReadOutbox: queue,
        call: (_, _) {
          called.complete();
          return response.future;
        },
      ),
    );
    final sending = group.markRead('group', 5);
    await called.future;
    await ChatReadOutbox('me', group: true).put('group', 10);
    response.complete({});
    await sending;
    expect(await queue.read(), {'group': 10});
  });

  test(
    'revoked group read remains pending without blocking another group',
    () async {
      final queue = ChatReadOutbox('me', group: true);
      await queue.put('revoked', 5);
      await queue.put('active', 10);
      final calls = <String>[];
      final repo = MessagingRepository(
        account: 'me',
        groupReadOutbox: queue,
        call: (_, params) async {
          final id = params['groupId'] as String;
          calls.add(id);
          if (id == 'revoked') {
            throw const AuthFailure('CHAT_GROUP_ACCESS_DENIED', 'not a member');
          }
          return {};
        },
      );
      await repo.retryPendingReads(isActive: () => true);
      expect(calls, ['revoked', 'active']);
      expect(await queue.read(), {'revoked': 5});
    },
  );

  test(
    'queue kinds are checked and empty group read creates no durable intent',
    () async {
      expect(
        () => MessagingRepository(
          account: 'me',
          readOutbox: ChatReadOutbox('me', group: true),
          call: (_, _) async => {},
        ),
        throwsArgumentError,
      );
      expect(
        () => MessagingRepository(
          account: 'me',
          groupReadOutbox: ChatReadOutbox('me'),
          call: (_, _) async => {},
        ),
        throwsArgumentError,
      );
      final queue = ChatReadOutbox('me', group: true);
      final group = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          groupReadOutbox: queue,
          call: (_, params) async {
            expect(params['sequence'], 0);
            return {};
          },
        ),
      );
      await group.markRead('group', 0);
      expect(await queue.read(), isEmpty);
    },
  );
}
