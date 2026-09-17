part of 'chat_history_store.dart';

extension LocalChatHistorySearch on ChatHistoryStore {
  /// Returns at most 20 messages on either side of the exact visible target.
  Future<List<Map<String, dynamic>>> context(
    String conversation, {
    required String messageId,
    required int sequence,
  }) async {
    if (messageId.isEmpty || sequence < 1 || sequence > 4294967295) {
      throw ArgumentError('Invalid message reference');
    }
    final id = await _conversation(conversation);
    return _db.transaction((tx) async {
      final older = await tx.query(
        'message',
        where: 'conversation=? AND stale=0 AND sequence<=?',
        whereArgs: [id, sequence],
        orderBy: 'sequence DESC',
        limit: 21,
      );
      final newer = await tx.query(
        'message',
        where: 'conversation=? AND stale=0 AND sequence>?',
        whereArgs: [id, sequence],
        orderBy: 'sequence ASC',
        limit: 20,
      );
      final messages = <Map<String, dynamic>>[];
      for (final row in [...older.reversed, ...newer]) {
        final plain = await ChatHistoryStore._cipher.decrypt(
          SecretBox.fromConcatenation(
            (row['payload'] as List).cast<int>(),
            nonceLength: 12,
            macLength: 16,
          ),
          secretKey: _key,
          aad: _aad(id, row['sequence'] as int),
        );
        final message = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(plain)) as Map,
        );
        if (message['messageType'] != 'hidden') messages.add(message);
      }
      if (!messages.any(
        (message) =>
            message['sequence'] == sequence &&
            message['messageId'] == messageId &&
            message['messageType'] != 'recalled',
      )) {
        throw StateError('The message is no longer available locally');
      }
      return messages;
    });
  }

  /// Searches only persisted, visible messages. No plaintext search index is
  /// written to disk. A transaction keeps deletion and pagination consistent.
  Future<Map<String, dynamic>> search(
    String conversation, {
    String query = '',
    String? messageType,
    int? before,
    int limit = 30,
    bool Function()? isActive,
  }) async {
    void checkActive() {
      if (isActive != null && !isActive()) {
        throw StateError('Local history search was cancelled');
      }
    }

    checkActive();
    final needle = query.trim().toLowerCase();
    if (limit < 1 || limit > 200 || (before != null && before < 1)) {
      throw ArgumentError('Invalid search page');
    }
    if (needle.isEmpty && messageType == null) {
      return {'messages': <Map<String, dynamic>>[], 'hasMore': false};
    }
    final id = await _conversation(conversation);
    return _db.transaction((tx) async {
      checkActive();
      final matches = <Map<String, dynamic>>[];
      var cursor = before;
      while (matches.length <= limit) {
        checkActive();
        final rows = await tx.query(
          'message',
          where: cursor == null
              ? 'conversation=? AND stale=0'
              : 'conversation=? AND stale=0 AND sequence<?',
          whereArgs: [id, ?cursor],
          orderBy: 'sequence DESC',
          limit: 50,
        );
        for (final row in rows) {
          checkActive();
          final plain = await ChatHistoryStore._cipher.decrypt(
            SecretBox.fromConcatenation(
              (row['payload'] as List).cast<int>(),
              nonceLength: 12,
              macLength: 16,
            ),
            secretKey: _key,
            aad: _aad(id, row['sequence'] as int),
          );
          final message = Map<String, dynamic>.from(
            jsonDecode(utf8.decode(plain)) as Map,
          );
          final type = message['messageType'];
          if (type == 'hidden' || type == 'recalled') continue;
          if (messageType != null && type != messageType) continue;
          if (needle.isNotEmpty &&
              ![message['text'], message['fileName']].any(
                (value) =>
                    value is String && value.toLowerCase().contains(needle),
              )) {
            continue;
          }
          matches.add({...message, 'status': 'sent'});
          if (matches.length > limit) break;
        }
        if (rows.length < 50 || matches.length > limit) break;
        cursor = rows.last['sequence'] as int;
      }
      checkActive();
      return {
        'messages': matches.take(limit).toList().reversed.toList(),
        'hasMore': matches.length > limit,
        'localOnly': true,
      };
    });
  }
}
