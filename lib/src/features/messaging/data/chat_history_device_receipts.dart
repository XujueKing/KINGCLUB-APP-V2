part of 'chat_history_store.dart';

Future<void> _createDeviceReceipts(DatabaseExecutor db) => db.execute(
  'CREATE TABLE IF NOT EXISTS history_device_receipt (conversation TEXT NOT NULL, messageId TEXT NOT NULL, target BLOB NOT NULL, confirmed INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(conversation,messageId))',
);

extension ChatHistoryDeviceReceipts on ChatHistoryStore {
  Future<void> _queueDeviceReceipts(
    Transaction tx,
    String conversation,
    String id,
    List<Map<String, dynamic>> messages,
  ) async {
    if (!conversation.startsWith('direct:') &&
        !conversation.startsWith('group:')) {
      return;
    }
    final ids = messages
        .map((m) => m['messageId'])
        .whereType<String>()
        .where(
          (id) => RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(id),
        )
        .toSet();
    if (ids.isEmpty) return;
    final target = await ChatHistoryStore._cipher.encrypt(
      utf8.encode(conversation),
      secretKey: _key,
      aad: _aad(id, -2),
    );
    final batch = tx.batch();
    for (final messageId in ids) {
      batch.insert('history_device_receipt', {
        'conversation': id,
        'messageId': messageId,
        'target': target.concatenation(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, List<String>>> pendingDeviceReceipts() async {
    final rows = await _db.query(
      'history_device_receipt',
      where: 'confirmed=0',
      orderBy: 'rowid',
      limit: 100,
    );
    final result = <String, List<String>>{};
    final targets = <String, String>{};
    for (final row in rows) {
      final id = row['conversation'] as String;
      var target = targets[id];
      if (target == null) {
        final bytes = await ChatHistoryStore._cipher.decrypt(
          SecretBox.fromConcatenation(
            (row['target'] as List).cast<int>(),
            nonceLength: 12,
            macLength: 16,
          ),
          secretKey: _key,
          aad: _aad(id, -2),
        );
        target = utf8.decode(bytes);
        targets[id] = target;
      }
      (result[target] ??= []).add(row['messageId'] as String);
    }
    return result;
  }

  Future<void> settleDeviceReceipts(
    String conversation,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return;
    if (ids.length > 100) throw ArgumentError('Receipt batch too large');
    final id = await _conversation(conversation);
    await _db.update(
      'history_device_receipt',
      {'confirmed': 1},
      where:
          'conversation=? AND messageId IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: [id, ...ids],
    );
  }
}
