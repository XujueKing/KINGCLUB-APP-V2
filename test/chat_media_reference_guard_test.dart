import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'source leases protect cleanup without becoming pending messages',
    () async {
      final writer = SecureChatOutbox('a');
      final history = SecureChatOutbox('a');
      final release = await writer.holdMediaSource({
        'messageType': 'voice',
        'voiceAssetId': 'asset',
        'authorization': 'must-not-leak',
        'text': 'not-a-message',
      });
      try {
        expect(await history.read(), isEmpty);
        await history.protectReferences((read) async {
          expect(await read(), [
            {'sender': 'a', 'messageType': 'voice', 'voiceAssetId': 'asset'},
          ]);
        });
        await SecureChatOutbox('b').protectReferences((read) async {
          expect(await read(), isEmpty);
        });
      } finally {
        await release();
        await release();
      }
      await history.protectReferences(
        (read) async => expect(await read(), isEmpty),
      );
    },
  );

  test(
    'cleanup keeps queue references stable and releases guard after failure',
    () async {
      final queue = SecureChatOutbox('a');
      final entered = Completer<void>(), proceed = Completer<void>();
      final cleanup = SecureChatOutbox('a')
          .protectReferences<void>((read) async {
            expect(await read(), isEmpty);
            entered.complete();
            await proceed.future;
            expect(await read(), isEmpty);
            throw StateError('filesystem busy');
          });
      final failed = expectLater(cleanup, throwsStateError);
      await entered.future;
      var published = false;
      final write = queue.put({'clientMessageId': 'new', 'sender': 'a'}).then((
        _,
      ) {
        published = true;
      });
      // A different account remains usable while this account is protected.
      await SecureChatOutbox('b')
          .put({'clientMessageId': 'other', 'sender': 'b'});
      expect(published, isFalse);
      proceed.complete();
      await failed;
      await write;
      expect((await queue.read()).single['clientMessageId'], 'new');
    },
  );
}
