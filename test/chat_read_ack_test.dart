import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_read_outbox.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final group in [false, true]) {
    for (final value in [null, 4, '5', 5.0, 4294967296]) {
      test(
        '${group ? "group" : "direct"} invalid acknowledgement $value stays pending',
        () async {
          var now = DateTime.utc(2026, 9, 16);
          final queue = ChatReadOutbox('me', group: group);
          var result = <String, dynamic>{
            'readSequence': value,
            'groupId': 'target',
          };
          final notifications = <String>[];
          final subscription = MessagingRepository.readChanges('me')
              .listen(notifications.add);
          addTearDown(subscription.cancel);
          final repo = MessagingRepository(
            account: 'me',
            readRetryClock: () => now,
            readOutbox: group ? null : queue,
            groupReadOutbox: group ? queue : null,
            call: (_, _) async => result,
          );
          await expectLater(
            group
                ? repo.markGroupRead('target', 5)
                : repo.markRead('target', 5),
            throwsFormatException,
          );
          expect(await queue.read(), {'target': 5});
          await repo.retryPendingReads(isActive: () => true);
          await Future<void>.delayed(Duration.zero);
          expect(await queue.read(), {'target': 5});
          // One local-read notification is emitted when the intent is saved.
          // Invalid server acknowledgements must not add another notification.
          expect(notifications, ['me']);
          result = {'readSequence': 7, 'groupId': 'target'};
          now = now.add(const Duration(minutes: 5));
          await repo.retryPendingReads(isActive: () => true);
          await Future<void>.delayed(Duration.zero);
          expect(await queue.read(), isEmpty);
          expect(notifications, ['me', 'me']);
        },
      );
    }
  }
  for (final group in [false, true]) {
    test(
      'malformed ${group ? "group" : "direct"} read cannot starve healthy reads',
      () async {
        var now = DateTime.utc(2026, 9, 16);
        final direct = ChatReadOutbox('me');
        final groups = ChatReadOutbox('me', group: true);
        final affected = group ? groups : direct;
        await affected.put('broken', 5);
        await affected.put('healthy', 8);
        if (!group) await groups.put('healthy-group', 9);
        var malformed = true;
        final calls = <String>[];
        final repo = MessagingRepository(
          account: 'me',
          readOutbox: direct,
          groupReadOutbox: groups,
          readRetryClock: () => now,
          call: (_, params) async {
            final target = (params['groupId'] ?? params['peer']) as String;
            calls.add(target);
            if (target == 'broken' && malformed) return {};
            return {
              'readSequence': params['sequence'],
              'groupId': params['groupId'],
            };
          },
        );
        await repo.retryPendingReads(isActive: () => true);
        expect(calls, ['broken', 'healthy', if (!group) 'healthy-group']);
        expect(await affected.read(), {'broken': 5});
        if (!group) expect(await groups.read(), isEmpty);
        calls.clear();
        await repo.retryPendingReads(isActive: () => true);
        expect(calls, isEmpty);
        malformed = false;
        now = now.add(const Duration(minutes: 5));
        await repo.retryPendingReads(isActive: () => true);
        expect(calls, ['broken']);
        expect(await affected.read(), isEmpty);
      },
    );
  }
  test(
    'another group acknowledgement cannot erase the intended group',
    () async {
      final queue = ChatReadOutbox('me', group: true);
      final repo = MessagingRepository(
        account: 'me',
        groupReadOutbox: queue,
        call: (_, _) async => {'groupId': 'other', 'readSequence': 100},
      );
      await expectLater(repo.markGroupRead('target', 5), throwsFormatException);
      expect(await queue.read(), {'target': 5});
      await repo.retryPendingReads(isActive: () => true);
      expect(await queue.read(), {'target': 5});
    },
  );
}
