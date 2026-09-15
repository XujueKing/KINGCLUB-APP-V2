import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_text_draft_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  ChatTextDraftStore store([String account = 'a', String target = 'peer:b']) =>
      ChatTextDraftStore(account, target, () async {});

  test(
    'reopen preserves reply and stable identity with account/target isolation',
    () async {
      final draft = ChatTextDraft(
        'unfinished message',
        replyTo: '11111111-1111-4111-8111-111111111111',
        preview: 'quoted message',
      );
      await store().write(draft);
      final reopened = await store().read();
      expect(reopened!.toJson(), draft.toJson());
      expect(await store('other').read(), isNull);
      expect(await store('a', 'group:b').read(), isNull);
    },
  );

  test(
    'late queued cleanup preserves replacement; clear follows pending writes',
    () async {
      final first = ChatTextDraft('first'), second = ChatTextDraft('second');
      await store().write(first);
      final replacement = store().write(second);
      final cleanup = store().remove(first.id);
      await Future.wait([replacement, cleanup]);
      expect((await store().read())!.id, second.id);
      await Future.wait([
        store().write(first),
        store().write(ChatTextDraft('')),
      ]);
      expect(await store().read(), isNull);
    },
  );

  test('expired session cannot overwrite or remove saved draft', () async {
    final draft = ChatTextDraft('keep');
    await store().write(draft);
    final expired = ChatTextDraftStore(
      'a',
      'peer:b',
      () async => throw StateError('expired'),
    );
    await expectLater(expired.read(), throwsStateError);
    await expectLater(
      expired.write(ChatTextDraft('overwrite')),
      throwsStateError,
    );
    await expectLater(expired.remove(draft.id), throwsStateError);
    expect((await store().read())!.id, draft.id);
  });

  test('invalid drafts leave previous valid value intact', () async {
    final draft = ChatTextDraft('keep');
    await store().write(draft);
    await expectLater(
      store().write(ChatTextDraft('x' * 4001)),
      throwsFormatException,
    );
    await expectLater(
      store().write(ChatTextDraft('reply', replyTo: 'invalid')),
      throwsFormatException,
    );
    expect((await store().read())!.id, draft.id);
  });
}
