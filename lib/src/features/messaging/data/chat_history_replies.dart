part of 'chat_history_store.dart';

Future<void> _sanitizeLegacyReplies(
  DatabaseExecutor db,
  SecretKey key,
  String account,
) async {
  List<int> aad(Map<String, Object?> row) => utf8.encode(
    'chat-history-v1|$account|${row['conversation']}|${row['sequence']}',
  );
  Future<Map<String, dynamic>> decode(Map<String, Object?> row) async {
    final bytes = await ChatHistoryStore._cipher.decrypt(
      SecretBox.fromConcatenation(
        (row['payload'] as List).cast<int>(),
        nonceLength: 12,
        macLength: 16,
      ),
      secretKey: key,
      aad: aad(row),
    );
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
  }

  var offset = 0;
  while (true) {
    final rows = await db.query(
      'message',
      orderBy: 'conversation,sequence',
      limit: 50,
      offset: offset,
    );
    for (final row in rows) {
      final value = await decode(row);
      final reply = ChatReply.tryParse(value['reply']);
      if (reply == null || !reply.available) continue;
      final sources = await db.query(
        'message',
        where: 'conversation=? AND sequence=?',
        whereArgs: [row['conversation'], reply.sequence],
      );
      final state = await db.query(
        'conversation',
        columns: ['hiddenThrough'],
        where: 'id=?',
        whereArgs: [row['conversation']],
      );
      final floor = state.isEmpty ? 0 : state.single['hiddenThrough'] as int;
      var available = false;
      if (sources.isNotEmpty &&
          reply.sequence! > floor &&
          sources.single['stale'] != 1) {
        final source = await decode(sources.single);
        available =
            source['messageId'] == reply.messageId &&
            !const {'hidden', 'recalled'}.contains(source['messageType']);
      }
      if (available) continue;
      // A missing source cannot prove whether it was deleted or never cached.
      // Drop only its legacy preview; an authorized refresh can restore it.
      value['reply'] = {'messageId': reply.messageId, 'available': false};
      final box = await ChatHistoryStore._cipher.encrypt(
        utf8.encode(jsonEncode(value)),
        secretKey: key,
        aad: aad(row),
      );
      await db.update(
        'message',
        {'payload': box.concatenation()},
        where: 'conversation=? AND sequence=?',
        whereArgs: [row['conversation'], row['sequence']],
      );
    }
    if (rows.length < 50) return;
    offset += rows.length;
  }
}

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
