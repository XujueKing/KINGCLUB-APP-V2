import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_text_draft_store.dart';
import 'package:kingclub/src/features/messaging/presentation/conversation_draft_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  ChatTextDraftStore store(String account, String target) =>
      ChatTextDraftStore(account, target, () async {});
  Future<ChatTextDraftStore> open(String a, String t) async => store(a, t);
  Widget page(
    String account, {
    String target = 'peer:b',
    Future<ChatTextDraftStore> Function(String, String)? factory,
  }) => MaterialApp(
    home: ConversationDraftPreview(
      account: account,
      target: target,
      preview: 'server preview',
      style: const TextStyle(fontSize: 13),
      openStore: factory ?? open,
    ),
  );

  testWidgets(
    'restores draft, updates edits and only clears queued draft identity',
    (tester) async {
      final first = ChatTextDraft('unfinished');
      await store('a', 'peer:b').write(first);
      await tester.pumpWidget(page('a'));
      await tester.pumpAndSettle();
      expect(find.textContaining('unfinished'), findsOneWidget);
      final newer = ChatTextDraft('newer edit');
      await store('a', 'peer:b').write(newer);
      await tester.pumpAndSettle();
      expect(find.textContaining('newer edit'), findsOneWidget);
      await store('a', 'peer:b').remove(first.id);
      await tester.pumpAndSettle();
      expect(find.textContaining('newer edit'), findsOneWidget);
      await store('a', 'peer:b').remove(newer.id);
      await tester.pumpAndSettle();
      expect(find.text('server preview'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'isolates group and account drafts and clears on session change',
    (tester) async {
      await store('a', 'peer:b').write(ChatTextDraft('direct body'));
      await store('a', 'group:b').write(ChatTextDraft('group body'));
      await store('c', 'group:b').write(ChatTextDraft('other account'));
      await tester.pumpWidget(page('a', target: 'group:b'));
      await tester.pumpAndSettle();
      expect(find.textContaining('group body'), findsOneWidget);
      await store('a', 'peer:b').write(ChatTextDraft('ignored update'));
      await tester.pumpAndSettle();
      expect(find.textContaining('group body'), findsOneWidget);
      await tester.pumpWidget(page('c', target: 'group:b'));
      await tester.pumpAndSettle();
      expect(find.textContaining('other account'), findsOneWidget);
      expect(find.textContaining('group body'), findsNothing);
      SecureSessionStore.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('server preview'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('late old-account open does not contaminate new account', (
    tester,
  ) async {
    final old = Completer<ChatTextDraftStore>();
    await store('a', 'peer:b').write(ChatTextDraft('old secret'));
    await store('c', 'peer:b').write(ChatTextDraft('current body'));
    Future<ChatTextDraftStore> delayed(String a, String t) =>
        a == 'a' ? old.future : open(a, t);
    await tester.pumpWidget(page('a', factory: delayed));
    await tester.pumpWidget(page('c', factory: delayed));
    old.complete(store('a', 'peer:b'));
    await tester.pumpAndSettle();
    expect(find.textContaining('old secret'), findsNothing);
    expect(find.textContaining('current body'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
