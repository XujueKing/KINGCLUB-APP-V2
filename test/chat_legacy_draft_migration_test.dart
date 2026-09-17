import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_text_draft_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'legacy quotes sanitize once while preserving text and valid paged source',
    () async {
      final dir = await Directory.systemTemp.createTemp('legacy-drafts-');
      final key = await AesGcm.with256bits().newSecretKey();
      Future<ChatHistoryStore> open(bool migrate) =>
          ChatHistoryStore.openDatabaseWithKey(
            factory: databaseFactoryFfi,
            file: '${dir.path}/history.db',
            key: key,
            account: 'me',
            draftStorage: migrate ? const FlutterSecureStorage() : null,
          );
      const sourceId = '11111111-1111-4111-8111-111111111111';
      Map<String, dynamic> row(int sequence) => {
        'messageId': sequence == 1 ? sourceId : 'row-$sequence',
        'clientMessageId': 'client-$sequence',
        'sequence': sequence,
        'sender': 'peer',
        'messageType': 'text',
        'text': 'original',
      };
      var history = await open(false);
      await history.commit('direct:valid', [
        for (var i = 1; i <= 51; i++) row(i),
      ], expectedEpoch: 0);
      await history.commit('group:deleted', [
        {...row(1), 'messageType': 'hidden'},
      ], expectedEpoch: 0);
      await history.close();
      ChatTextDraftStore draft(String account, String target) =>
          ChatTextDraftStore(account, target, () async {});
      for (final target in ['peer:valid', 'group:deleted', 'peer:missing']) {
        await draft('me', target).write(
          ChatTextDraft(
            'keep $target',
            replyTo: sourceId,
            preview: 'old preview',
          ),
        );
        await draft('other', target).write(
          ChatTextDraft('other', replyTo: sourceId, preview: 'other preview'),
        );
      }
      history = await open(true);
      await history.close();
      for (final target in ['group:deleted', 'peer:missing']) {
        final value = await draft('me', target).read();
        expect(value!.text, 'keep $target');
        expect(value.replyTo, isNull);
        expect(value.preview, isNull);
        expect((await draft('other', target).read())!.preview, 'other preview');
      }
      expect((await draft('me', 'peer:valid').read())!.replyTo, sourceId);
      // The upgrade is one-time; future valid drafts must not be treated as legacy.
      final future = ChatTextDraft(
        'future',
        replyTo: sourceId,
        preview: 'future preview',
      );
      await draft('me', 'peer:new').write(future);
      history = await open(true);
      await history.close();
      expect((await draft('me', 'peer:new').read())!.toJson(), future.toJson());
      await dir.delete(recursive: true);
    },
  );
}
