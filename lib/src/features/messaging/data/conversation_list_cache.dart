part of 'chat_history_store.dart';

Future<void> _createConversationListCache(DatabaseExecutor db) => db.execute(
  'CREATE TABLE conversation_list_cache (id INTEGER PRIMARY KEY CHECK(id=1), payload BLOB NOT NULL)',
);

extension ConversationListCache on ChatHistoryStore {
  List<int> get _listAad =>
      utf8.encode(jsonEncode(['conversation-list-v1', account]));

  /// Display-only snapshot. Never grants send, membership or media permissions.
  Future<void> saveConversationList(List<Map<String, dynamic>> items) async {
    const fields = {
      'kind',
      'peer',
      'groupId',
      'nickname',
      'remark',
      'preview',
      'messageDate',
      'lastSequence',
      'unreadCount',
      'relayUnreadCount',
      'muted',
      'pinned',
      'localOnly',
    };
    final projected = items
        .map(
          (item) => {
            for (final entry in item.entries)
              if (fields.contains(entry.key)) entry.key: entry.value,
          },
        )
        .toList();
    final bytes = utf8.encode(jsonEncode(projected));
    if (bytes.length > 2097152) {
      throw const FormatException('Conversation snapshot too large');
    }
    // Serialize encryption and the write with history cleanup. A save already
    // in progress must finish before clear removes the corresponding row.
    await _db.transaction((tx) => _writeConversationList(tx, bytes));
  }

  Future<List<Map<String, dynamic>>> readConversationList() async {
    return _readConversationList(_db);
  }

  Future<void> _writeConversationList(
    DatabaseExecutor db,
    List<int> bytes,
  ) async {
    final box = await ChatHistoryStore._cipher.encrypt(
      bytes,
      secretKey: _key,
      aad: _listAad,
    );
    await db.insert('conversation_list_cache', {
      'id': 1,
      'payload': box.concatenation(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _removeConversationListEntry(
    Transaction tx,
    String conversation,
  ) async {
    final rows = await _readConversationList(tx);
    final previousLength = rows.length;
    rows.removeWhere(
      (row) =>
          conversation ==
          (row['kind'] == 'group'
              ? 'group:${row['groupId']}'
              : 'direct:${row['peer']}'),
    );
    if (rows.length != previousLength) {
      await _writeConversationList(tx, utf8.encode(jsonEncode(rows)));
    }
  }

  Future<List<Map<String, dynamic>>> _readConversationList(
    DatabaseExecutor db,
  ) async {
    final rows = await db.query('conversation_list_cache', where: 'id=1');
    if (rows.isEmpty) return [];
    final bytes = await ChatHistoryStore._cipher.decrypt(
      SecretBox.fromConcatenation(
        (rows.single['payload'] as List).cast<int>(),
        nonceLength: 12,
        macLength: 16,
      ),
      secretKey: _key,
      aad: _listAad,
    );
    final decoded = jsonDecode(utf8.decode(bytes)) as List;
    return decoded
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
  }
}
