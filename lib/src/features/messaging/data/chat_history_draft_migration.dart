part of 'chat_history_store.dart';

extension _HistoryDraftMigration on ChatHistoryStore {
  Future<void> _sanitizeLegacyDraftReplies() async {
    final storage = _draftStorage;
    if (storage == null) return;
    final marker =
        'kingclub.text-draft-history-v1.${await ChatHistoryStore._hash(account)}';
    if (await storage.read(key: marker) == 'done') return;
    const prefix = 'kingclub.text-draft.';
    final values = await storage.readAll();
    for (final entry in values.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      late String target;
      late ChatTextDraft draft;
      try {
        final scope = jsonDecode(
          utf8.decode(base64Url.decode(entry.key.substring(prefix.length))),
        );
        if (scope is! List ||
            scope.length != 2 ||
            scope[0] != account ||
            scope[1] is! String) {
          continue;
        }
        target = scope[1] as String;
        if (!target.startsWith('peer:') && !target.startsWith('group:')) {
          continue;
        }
        draft = ChatTextDraft.parse(entry.value);
      } on FormatException {
        continue;
      }
      final reply = draft.replyTo;
      if (reply == null) continue;
      final conversation = target.startsWith('peer:')
          ? 'direct:${target.substring(5)}'
          : target;
      int? before;
      var found = false;
      while (true) {
        final page = await read(conversation, before: before);
        for (final message in page.messages) {
          if (message['messageId'] == reply &&
              (message['sequence'] as int) > page.hiddenThrough &&
              !const {'hidden', 'recalled'}.contains(message['messageType'])) {
            found = true;
            break;
          }
        }
        if (found || page.messages.length < 50) break;
        before = page.messages.first['sequence'] as int;
      }
      if (!found) {
        await ChatTextDraftStore(
          account,
          target,
          () async {},
          storage: storage,
        ).redactReply({reply});
      }
    }
    await storage.write(key: marker, value: 'done');
  }
}
