part of 'chat_history_store.dart';

Future<void> _createNearbyServerPresence(DatabaseExecutor db) => db.execute(
  'CREATE TABLE nearby_server_presence (member TEXT NOT NULL, id TEXT NOT NULL, PRIMARY KEY(member,id))',
);

const _notServerPresent =
    'NOT EXISTS (SELECT 1 FROM nearby_server_presence p '
    'WHERE p.member=nearby_message.member AND p.id=nearby_message.id)';

Future<void> _createNearbyMessages(DatabaseExecutor db) async {
  await db.execute(
    'CREATE TABLE nearby_message (peer TEXT NOT NULL, id TEXT NOT NULL, outgoing INTEGER NOT NULL, delivered INTEGER NOT NULL DEFAULT 0, created INTEGER NOT NULL, payload BLOB NOT NULL, serverId TEXT, member TEXT, hidden INTEGER NOT NULL DEFAULT 0, wasRead INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(peer,id,outgoing))',
  );
  await _createNearbyMemberIndex(db);
}

Future<void> _createNearbyMemberIndex(DatabaseExecutor db) => db.execute(
  'CREATE INDEX IF NOT EXISTS nearby_member_message ON nearby_message(member,id,outgoing)',
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
    String? peerAccount,
  }) async {
    if (!RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
        ).hasMatch(id) ||
        text.isEmpty ||
        text.length > 4000) {
      throw ArgumentError('Invalid nearby text');
    }
    final peer = await _nearbyPeer(peerId);
    if (peerAccount != null &&
        (peerAccount == account ||
            !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(peerAccount))) {
      throw ArgumentError('Invalid peer member');
    }
    final member = peerAccount == null
        ? null
        : await _conversation('direct:$peerAccount');
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
        if (await _nearbyText(rows.single) != text ||
            (member != null &&
                rows.single['member'] != null &&
                rows.single['member'] != member)) {
          throw StateError('Nearby message identity conflict');
        }
        if (member != null && rows.single['member'] == null) {
          await tx.update(
            'nearby_message',
            {'member': member},
            where: 'peer=? AND id=? AND outgoing=?',
            whereArgs: [peer, id, outgoing ? 1 : 0],
          );
        }
        return;
      }
      await tx.insert('nearby_message', {
        'peer': peer,
        'id': id,
        'outgoing': outgoing ? 1 : 0,
        'created': DateTime.now().millisecondsSinceEpoch,
        'payload': box.concatenation(),
        'member': member,
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
      where: pendingOnly
          ? 'peer=? AND outgoing=1 AND delivered=0 AND serverId IS NULL'
          : 'peer=?',
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
        'serverMessageId': row['serverId'],
      });
    }
    return result;
  }

  /// Member-scoped local additions to confirmed history, without fake sequences.
  /// One logical message may have travelled through several devices. A server
  /// association on any copy suppresses all copies, including tombstones.
  Future<List<Map<String, dynamic>>> nearbyMemberMessages(
    String peerAccount, {
    int limit = 100,
    bool forPreview = false,
  }) async {
    if (peerAccount == account ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(peerAccount) ||
        limit < 1 ||
        limit > 200) {
      throw ArgumentError('Invalid member history scope');
    }
    final member = await _conversation('direct:$peerAccount');
    return _db.transaction((tx) async {
      final groups = await tx.rawQuery(
        'SELECT id, outgoing, MIN(created) AS created, MAX(delivered) AS delivered, MAX(wasRead) AS wasRead '
        'FROM nearby_message WHERE member=? '
        '${forPreview ? 'AND $_notServerPresent ' : ''}GROUP BY id, outgoing '
        'HAVING MAX(serverId IS NOT NULL)=0 AND MAX(hidden)=0 '
        '${forPreview ? 'AND (outgoing=0 OR MAX(delivered)=1) ' : ''}'
        'ORDER BY created DESC, id DESC, outgoing DESC LIMIT ?',
        [member, limit],
      );
      final result = <Map<String, dynamic>>[];
      for (final group in groups) {
        final copies = await tx.query(
          'nearby_message',
          where: 'member=? AND id=? AND outgoing=?',
          whereArgs: [member, group['id'], group['outgoing']],
        );
        final text = await _nearbyText(copies.first);
        for (final copy in copies.skip(1)) {
          if (await _nearbyText(copy) != text) {
            throw StateError('Member message identity conflict');
          }
        }
        result.add({
          'id': group['id'],
          'text': text,
          'outgoing': group['outgoing'] == 1,
          'delivered': group['delivered'] == 1,
          'created': group['created'],
          'serverMessageId': null,
          'read': group['wasRead'] == 1,
        });
      }
      return result;
    });
  }

  Future<int> nearbyUnreadCount({String? peerAccount}) async {
    if (peerAccount != null &&
        (peerAccount == account ||
            !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(peerAccount))) {
      throw ArgumentError('Invalid unread scope');
    }
    final member = peerAccount == null
        ? null
        : await _conversation('direct:$peerAccount');
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM (SELECT member,id FROM nearby_message '
      'WHERE outgoing=0 AND member IS NOT NULL AND $_notServerPresent ${member == null ? '' : 'AND member=? '}'
      'GROUP BY member,id HAVING MAX(wasRead)=0 AND MAX(hidden)=0 AND MAX(serverId IS NOT NULL)=0)',
      [?member],
    );
    return rows.single['count'] as int;
  }

  /// Keyset pagination remains stable when earlier rows are read/cleared while
  /// receipt checks are running. This returns identifiers, never message text.
  Future<List<String>> nearbyUnreadIds({
    String? afterId,
    int limit = 200,
  }) async {
    if (limit < 1 ||
        limit > 200 ||
        (afterId != null &&
            !RegExp(
              r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
            ).hasMatch(afterId))) {
      throw ArgumentError('Invalid unread cursor');
    }
    final rows = await _db.rawQuery(
      'SELECT DISTINCT id FROM (SELECT member,id FROM nearby_message '
      'WHERE outgoing=0 AND member IS NOT NULL AND $_notServerPresent GROUP BY member,id '
      'HAVING MAX(wasRead)=0 AND MAX(hidden)=0 AND MAX(serverId IS NOT NULL)=0) '
      '${afterId == null ? '' : 'WHERE id>? '}ORDER BY id LIMIT ?',
      [?afterId, limit],
    );
    return rows.map((row) => row['id'] as String).toList();
  }

  /// This separate marker is server presence, not a local or remote read receipt.
  Future<void> confirmNearbyServerPresence(
    String peerAccount,
    List<String> ids,
  ) async {
    if (peerAccount == account ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(peerAccount) ||
        ids.length > 200 ||
        ids.any(
          (id) => !RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
          ).hasMatch(id),
        )) {
      throw ArgumentError('Invalid server presence scope');
    }
    if (ids.isEmpty) return;
    final member = await _conversation('direct:$peerAccount');
    await _db.transaction((tx) async {
      for (final id in ids.toSet()) {
        await tx.rawInsert(
          'INSERT OR IGNORE INTO nearby_server_presence(member,id) '
          'SELECT member,id FROM nearby_message WHERE member=? AND id=? AND outgoing=0 LIMIT 1',
          [member, id],
        );
      }
    });
  }

  /// Marks only the displayed snapshot. A later arrival must remain unread.
  Future<int> markNearbyMemberRead(String peerAccount, List<String> ids) async {
    if (peerAccount == account ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(peerAccount) ||
        ids.length > 200 ||
        ids.any(
          (id) => !RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
          ).hasMatch(id),
        )) {
      throw ArgumentError('Invalid read snapshot');
    }
    if (ids.isEmpty) return 0;
    final member = await _conversation('direct:$peerAccount');
    return _db.update(
      'nearby_message',
      {'wasRead': 1},
      where:
          'member=? AND outgoing=0 AND wasRead=0 AND id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: [member, ...ids],
    );
  }

  /// Reconciles only authenticated service history, never peer-supplied claims.
  /// Server persistence and a recipient receipt remain distinct states.
  Future<int> reconcileNearbyText({
    required String peerId,
    required String peerAccount,
    required List<Map<String, dynamic>> confirmed,
  }) async {
    if (peerAccount == account ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(peerAccount) ||
        confirmed.length > 200) {
      throw ArgumentError('Invalid reconciliation scope');
    }
    final peer = await _nearbyPeer(peerId);
    final messages = confirmed.map(_payload).toList();
    return _db.transaction(
      (tx) => _reconcileNearbyRows(tx, 'peer', peer, peerAccount, messages),
    );
  }

  Future<int> _reconcileNearbyRows(
    DatabaseExecutor tx,
    String scopeColumn,
    String scope,
    String peerAccount,
    List<Map<String, dynamic>> messages,
  ) async {
    var changed = 0;
    for (final message in messages) {
      if (message['groupId'] != null ||
          message['call'] != null ||
          ![
            null,
            'text',
            'hidden',
            'recalled',
          ].contains(message['messageType'])) {
        continue;
      }
      final outgoing =
          message['sender'] == account && message['recipient'] == peerAccount;
      final incoming =
          message['sender'] == peerAccount && message['recipient'] == account;
      if (!outgoing && !incoming) continue;
      final rows = await tx.query(
        'nearby_message',
        where: '$scopeColumn=? AND id=? AND outgoing=?',
        whereArgs: [scope, message['clientMessageId'], outgoing ? 1 : 0],
      );
      if (rows.isEmpty) continue;
      for (final row in rows) {
        final tombstone = [
          'hidden',
          'recalled',
        ].contains(message['messageType']);
        if ((!tombstone && await _nearbyText(row) != message['text']) ||
            (row['serverId'] != null &&
                row['serverId'] != message['messageId'])) {
          throw StateError('Peer/server message identity conflict');
        }
        if (row['serverId'] == null) {
          changed += await tx.update(
            'nearby_message',
            {'serverId': message['messageId']},
            where: 'peer=? AND id=? AND outgoing=?',
            whereArgs: [
              row['peer'],
              message['clientMessageId'],
              outgoing ? 1 : 0,
            ],
          );
        }
      }
    }
    return changed;
  }
}
