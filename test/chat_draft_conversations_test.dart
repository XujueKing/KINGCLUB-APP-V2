import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/chat_text_draft_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'enumerates own text drafts while excluding location and other accounts',
    () async {
      ChatTextDraftStore store(String account, String target) =>
          ChatTextDraftStore(account, target, () async {});
      await store('me', 'peer:friend').write(ChatTextDraft('unsent'));
      await store('me', 'group:room').write(ChatTextDraft('group unsent'));
      await store(
        'me',
        'location:peer:friend',
      ).write(ChatTextDraft('location json'));
      await store('other', 'peer:friend').write(ChatTextDraft('private'));
      final index = store('me', 'peer:friend');
      final drafts = await index.readConversations();
      expect(drafts.keys, unorderedEquals(['peer:friend', 'group:room']));
      expect(drafts['peer:friend']!.text, 'unsent');
      await index.remove(drafts['peer:friend']!.id);
      expect((await index.readConversations()).keys, ['group:room']);
    },
  );
  test('session invalidation refuses enumeration', () async {
    var invalid = false;
    final store = ChatTextDraftStore('me', 'peer:friend', () async {
      if (invalid) throw StateError('session changed');
    });
    await store.write(ChatTextDraft('private'));
    invalid = true;
    await expectLater(store.readConversations(), throwsStateError);
  });
}
