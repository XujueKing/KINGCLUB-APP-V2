part of 'chat_history_store.dart';

Future<void> _createNearbyMessages(DatabaseExecutor db) => db.execute(
  'CREATE TABLE nearby_message (peer TEXT NOT NULL, id TEXT NOT NULL, outgoing INTEGER NOT NULL, delivered INTEGER NOT NULL DEFAULT 0, created INTEGER NOT NULL, payload BLOB NOT NULL, PRIMARY KEY(peer,id,outgoing))',
);

/// Device-to-device local messages have no server sequence until reconciled.
/// This journal deliberately does not invent server-confirmed history entries.
extension NearbyMessageHistory on ChatHistoryStore {
  Future<String> _nearbyPeer(String peer) {
    if (!RegExp(r'^novovm-ed25519:[0-9a-f]{64}$').hasMatch(peer)) {
      throw ArgumentError('Invalid nearby peer identity');
    }
    return ChatHistoryStore._hash(jsonEncode(['nearby-v1', account, peer]));
  }

  List<int> _nearbyAad(String peer, String id, bool outgoing) => utf8.encode(
    jsonEncode(['nearby-message-v1', account, peer, id, outgoing]),
  );
  Future<String> _nearbyText(Map<String, Object?> row) async => utf8.decode(
    await ChatHistoryStore._cipher.decrypt(
      SecretBox.fromConcatenation(
        (row['payload'] as List).cast<int>(),
        nonceLength: 12,
        macLength: 16,
      ),
      secretKey: _key,
      aad: _nearbyAad(
        row['peer'] as String,
        row['id'] as String,
        row['outgoing'] == 1,
      ),
    ),
  );

  /// Returns after the transaction commits. Duplicate IDs must carry identical text.
  Future<void> persistNearbyText({
    required String peerId,
    required String id,
    required String text,
    required bool outgoing,
  }) async {
    if (!RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
        ).hasMatch(id) ||
        text.isEmpty ||
        text.length > 4000) {
      throw ArgumentError('Invalid nearby text');
    }
    final peer = await _nearbyPeer(peerId);
    final box = await ChatHistoryStore._cipher.encrypt(
      utf8.encode(text),
      secretKey: _key,
      aad: _nearbyAad(peer, id, outgoing),
    );
    await _db.transaction((tx) async {
      final rows = await tx.query(
        'nearby_message',
        where: 'peer=? AND id=? AND outgoing=?',
        whereArgs: [peer, id, outgoing ? 1 : 0],
      );
      if (rows.isNotEmpty) {
        if (await _nearbyText(rows.single) != text) {
          throw StateError('Nearby message identity conflict');
        }
        return;
      }
      await tx.insert('nearby_message', {
        'peer': peer,
        'id': id,
        'outgoing': outgoing ? 1 : 0,
        'created': DateTime.now().millisecondsSinceEpoch,
        'payload': box.concatenation(),
      });
    });
  }

  Future<bool> confirmNearbyReceipt({
    required String peerId,
    required String id,
  }) async {
    final peer = await _nearbyPeer(peerId);
    return await _db.update(
          'nearby_message',
          {'delivered': 1},
          where: 'peer=? AND id=? AND outgoing=1',
          whereArgs: [peer, id],
        ) ==
        1;
  }

  Future<List<Map<String, dynamic>>> nearbyMessages(
    String peerId, {
    bool pendingOnly = false,
    int limit = 100,
  }) async {
    if (limit < 1 || limit > 200) {
      throw ArgumentError('Invalid nearby history limit');
    }
    final peer = await _nearbyPeer(peerId);
    final rows = await _db.query(
      'nearby_message',
      where: pendingOnly ? 'peer=? AND outgoing=1 AND delivered=0' : 'peer=?',
      whereArgs: [peer],
      orderBy: pendingOnly ? 'created ASC, id ASC' : 'created DESC, id DESC',
      limit: limit,
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      result.add({
        'id': row['id'],
        'text': await _nearbyText(row),
        'outgoing': row['outgoing'] == 1,
        'delivered': row['delivered'] == 1,
        'created': row['created'],
      });
    }
    return result;
  }
}
