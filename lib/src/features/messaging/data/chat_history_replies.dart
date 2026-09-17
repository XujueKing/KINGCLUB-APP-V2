part of 'chat_history_store.dart';

extension _HistoryReplyCleanup on ChatHistoryStore {
  Future<void> _redactStoredReplies(
    Transaction tx,
    String conversation,
    Set<String> removedIds,
    int hiddenThrough,
  ) async {
    if (removedIds.isEmpty && hiddenThrough == 0) return;
    var after = 0;
    while (true) {
      final rows = await tx.query(
        'message',
        where: 'conversation=? AND sequence>?',
        whereArgs: [conversation, after],
        orderBy: 'sequence',
        limit: 50,
      );
      for (final row in rows) {
        final sequence = row['sequence'] as int;
        final aad = _aad(conversation, sequence);
        final plain = await ChatHistoryStore._cipher.decrypt(
          SecretBox.fromConcatenation(
            (row['payload'] as List).cast<int>(),
            nonceLength: 12,
            macLength: 16,
          ),
          secretKey: _key,
          aad: aad,
        );
        final value = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(plain)) as Map,
        );
        final reply = ChatReply.tryParse(value['reply']);
        if (reply == null ||
            !reply.available ||
            (!removedIds.contains(reply.messageId) &&
                reply.sequence! > hiddenThrough)) {
          continue;
        }
        value['reply'] = {'messageId': reply.messageId, 'available': false};
        final box = await ChatHistoryStore._cipher.encrypt(
          utf8.encode(jsonEncode(value)),
          secretKey: _key,
          aad: aad,
        );
        await tx.update(
          'message',
          {'payload': box.concatenation()},
          where: 'conversation=? AND sequence=?',
          whereArgs: [conversation, sequence],
        );
      }
      if (rows.length < 50) return;
      after = rows.last['sequence'] as int;
    }
  }
}
