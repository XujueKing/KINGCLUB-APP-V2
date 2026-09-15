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
          expect(notifications, isEmpty);
          result = {'readSequence': 7, 'groupId': 'target'};
          await repo.retryPendingReads(isActive: () => true);
          await Future<void>.delayed(Duration.zero);
          expect(await queue.read(), isEmpty);
          expect(notifications, ['me']);
        },
      );
    }
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
