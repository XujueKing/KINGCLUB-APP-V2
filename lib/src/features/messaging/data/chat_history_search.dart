part of 'chat_history_store.dart';

extension LocalChatHistorySearch on ChatHistoryStore {
  /// Searches only persisted, visible messages. No plaintext search index is
  /// written to disk. A transaction keeps deletion and pagination consistent.
  Future<Map<String, dynamic>> search(
    String conversation, {
    String query = '',
    String? messageType,
    int? before,
    int limit = 30,
  }) async {
    final needle = query.trim().toLowerCase();
    if (limit < 1 || limit > 200 || (before != null && before < 1)) {
      throw ArgumentError('Invalid search page');
    }
    if (needle.isEmpty && messageType == null) {
      return {'messages': <Map<String, dynamic>>[], 'hasMore': false};
    }
    final id = await _conversation(conversation);
    return _db.transaction((tx) async {
      final matches = <Map<String, dynamic>>[];
      var cursor = before;
      while (matches.length <= limit) {
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
      return {
        'messages': matches.take(limit).toList().reversed.toList(),
        'hasMore': matches.length > limit,
        'localOnly': true,
      };
    });
  }
}
