import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kingclub/src/features/messaging/data/chat_history_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_text_draft_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final mode in ['delete', 'clear', 'recall', 'floor']) {
    test('unopened draft cleanup and late write fence: $mode', () async {
      final dir = await Directory.systemTemp.createTemp('history-draft-');
      final store = await ChatHistoryStore.openDatabaseWithKey(
        factory: databaseFactoryFfi,
        file: '${dir.path}/history.db',
        key: await AesGcm.with256bits().newSecretKey(),
        account: 'me',
        draftStorage: const FlutterSecureStorage(),
      );
      const id = '11111111-1111-4111-8111-111111111111';
      final message = <String, dynamic>{
        'messageId': id,
        'clientMessageId': 'client',
        'sequence': 1,
        'sender': 'peer',
        'messageType': 'text',
        'text': 'private quote',
        'createdDate': '2026-09-17T00:00:00Z',
      };
      await store.commit('direct:peer', [message], expectedEpoch: 0);
      ChatTextDraftStore drafts(String account, String target) =>
          ChatTextDraftStore(account, target, () async {});
      final draft = ChatTextDraft(
        'keep input',
        replyTo: id,
        preview: 'private quote',
      );
      await drafts('me', 'peer:peer').write(draft);
      await drafts('other', 'peer:peer').write(draft);
      await drafts('me', 'group:peer').write(draft);
      if (mode == 'clear' || mode == 'delete') {
        await store.clear(
          'direct:peer',
          deletedMessageIds: mode == 'delete' ? {id} : null,
        );
      } else {
        await store.commit(
          'direct:peer',
          mode == 'recall'
              ? [
                  {...message, 'messageType': 'recalled', 'text': ''},
                ]
              : [],
          expectedEpoch: 0,
          hiddenThrough: mode == 'floor' ? 1 : 0,
        );
      }
      await store.close();
      final saved = await drafts('me', 'peer:peer').read();
      expect(saved!.text, 'keep input');
      expect(saved.id, draft.id);
      expect(saved.replyTo, isNull);
      expect(saved.preview, isNull);
      await drafts('me', 'peer:peer').write(draft);
      expect((await drafts('me', 'peer:peer').read())!.preview, isNull);
      expect(
        (await drafts('other', 'peer:peer').read())!.preview,
        'private quote',
      );
      expect(
        (await drafts('me', 'group:peer').read())!.preview,
        'private quote',
      );
      await dir.delete(recursive: true);
    });
  }
}
