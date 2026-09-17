part of 'chat_history_store.dart';

class ConversationHistoryRemoval {
  ConversationHistoryRemoval(
    this.conversation, {
    Set<int>? sequences,
    this.hiddenThrough = 0,
  }) : sequences = sequences == null ? null : Set.unmodifiable(sequences);
  final String conversation;
  final Set<int>? sequences;
  final int hiddenThrough;

  /// Preserve other messages' counts; the next server refresh supplies the
  /// authoritative unread total and replacement preview after single deletion.
  bool applyTo(List<Map<String, dynamic>> rows) {
    var changed = false;
    rows.removeWhere((row) {
      final key = row['kind'] == 'group'
          ? 'group:${row['groupId']}'
          : 'direct:${row['peer']}';
      if (key != conversation) return false;
      if (sequences == null ||
          (hiddenThrough > 0 &&
              row['lastSequence'] is num &&
              (row['lastSequence'] as num) <= hiddenThrough)) {
        changed = true;
        return true;
      }
      if (sequences!.contains(row['lastSequence'])) {
        // A removed outgoing head must stop overriding the server's older,
        // still-visible preview (or its decision to omit the conversation).
        final wasConfirmed = row.remove('localConfirmed') != null;
        if (row['preview'] != '' || wasConfirmed) {
          row['preview'] = '';
          changed = true;
        }
      }
      return false;
    });
    return changed;
  }
}

Future<void> _createConversationListCache(DatabaseExecutor db) => db.execute(
  'CREATE TABLE conversation_list_cache (id INTEGER PRIMARY KEY CHECK(id=1), payload BLOB NOT NULL)',
);

/// Keep locally confirmed outgoing heads until the server list catches up.
List<Map<String, dynamic>> mergeConfirmedConversationRows(
  List<Map<String, dynamic>> local,
  List<Map<String, dynamic>> incoming, {
  List<Map<String, dynamic>> settledHeads = const [],
}) {
  String key(Map<String, dynamic> row) => row['kind'] == 'group'
      ? 'group:${row['groupId']}'
      : 'direct:${row['peer']}';
  final settled = {
    for (final row in settledHeads) key(row): row['lastSequence'] as num? ?? 0,
  };
  final rows = {
    for (final row in incoming) key(row): Map<String, dynamic>.from(row),
  };
  for (final row in local) {
    if (row['localConfirmed'] != true) continue;
    // A complete server snapshot requested after this confirmation is
    // authoritative. Only confirmations made during the request still bridge.
    if (settled.containsKey(key(row)) &&
        (row['lastSequence'] as num? ?? 0) <= settled[key(row)]!) {
      continue;
    }
    final server = rows[key(row)];
    if (server == null) {
      rows[key(row)] = Map<String, dynamic>.from(row);
    } else if ((server['lastSequence'] as num? ?? 0) <
        (row['lastSequence'] as num? ?? 0)) {
      rows[key(row)] = {
        ...server,
        for (final field in [
          'preview',
          'messageDate',
          'lastSequence',
          'localConfirmed',
        ])
          field: row[field],
      };
    }
  }
  return rows.values.toList();
}

extension ConversationListCache on ChatHistoryStore {
  List<int> get _listAad =>
      utf8.encode(jsonEncode(['conversation-list-v1', account]));

  /// Display-only snapshot. Never grants send, membership or media permissions.
  Future<void> saveConversationList(
    List<Map<String, dynamic>> items, {
    int? expectedRevision,
    List<Map<String, dynamic>> settledHeads = const [],
  }) async {
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
      'localConfirmed',
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
    await _db.transaction((tx) async {
      if (expectedRevision != null &&
          expectedRevision != _conversationListRevision) {
        return;
      }
      final merged = mergeConfirmedConversationRows(
        await _readConversationList(tx),
        projected,
        settledHeads: settledHeads,
      );
      await _writeConversationList(tx, utf8.encode(jsonEncode(merged)));
    });
  }

  Future<void> _recordOutgoingHead(
    Transaction tx,
    String conversation,
    Map<String, dynamic> message,
  ) async {
    final group = conversation.startsWith('group:');
    if (!group && !conversation.startsWith('direct:')) return;
    if (message['sender'] != account ||
        const {'hidden', 'recalled'}.contains(message['messageType'])) {
      return;
    }
    final rows = await _readConversationList(tx);
    final target = conversation.substring(group ? 6 : 7);
    final index = rows.indexWhere(
      (row) =>
          (row['kind'] == 'group') == group &&
          row[group ? 'groupId' : 'peer'] == target,
    );
    final previous = index < 0 ? <String, dynamic>{} : rows[index];
    if ((previous['lastSequence'] as num? ?? 0) >=
        (message['sequence'] as int)) {
      return;
    }
    final preview = switch (message['messageType']) {
      'image' => '[图片]',
      'video' => '[视频]',
      'voice' => '[语音]',
      'file' => '[文件]',
      'location' => '[位置]',
      _ => message['text'],
    };
    final row = <String, dynamic>{
      'kind': group ? 'group' : 'direct',
      group ? 'groupId' : 'peer': target,
      'nickname': group ? '群聊' : '好友',
      'unreadCount': 0,
      ...previous,
      'preview': preview,
      'messageDate': message['createdDate'],
      'lastSequence': message['sequence'],
      'localConfirmed': true,
    };
    if (index < 0) {
      rows.insert(0, row);
    } else {
      rows[index] = row;
    }
    await _writeConversationList(tx, utf8.encode(jsonEncode(rows)));
  }

  /// A missing paginated row is not proof of deletion. Query its history
  /// boundary before removing a locally confirmed bridge or retained messages.
  Future<void> reconcileHiddenConfirmedHeads({
    required List<Map<String, dynamic>> candidates,
    required List<Map<String, dynamic>> visible,
    required Future<Map<String, dynamic>> Function(bool group, String target)
    fetch,
    required bool Function() isActive,
  }) async {
    String key(Map<String, dynamic> row) => row['kind'] == 'group'
        ? 'group:${row['groupId']}'
        : 'direct:${row['peer']}';
    final seen = visible.map(key).toSet();
    for (final row in candidates) {
      if (!isActive()) return;
      if (row['localConfirmed'] != true || seen.contains(key(row))) continue;
      final group = row['kind'] == 'group';
      final target = row[group ? 'groupId' : 'peer'];
      if (target is! String || target.isEmpty) continue;
      try {
        final conversation = key(row);
        final saved = await read(conversation, limit: 1);
        if (!isActive()) return;
        final response = await fetch(group, target);
        if (!isActive()) return;
        final floor = (response['settings'] as Map?)?['hiddenThrough'];
        final version = response['historyVersion'];
        final membership = response['membershipVersion'];
        if (floor is! int ||
            floor <= saved.hiddenThrough ||
            version is! int ||
            version < 0 ||
            version != saved.historyVersion ||
            (group &&
                (membership is! int ||
                    membership != saved.membershipVersion))) {
          continue;
        }
        // Commit only the authoritative boundary. Do not mark messages read,
        // advance pagination, or adopt a membership/history revision here.
        await commit(
          conversation,
          const [],
          expectedEpoch: saved.epoch,
          hiddenThrough: floor,
          historyVersion: version,
          membershipVersion: group ? membership as int : null,
        );
      } catch (_) {
        // Offline, denied and malformed responses never imply deletion.
      }
    }
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
    ConversationHistoryRemoval removal,
  ) async {
    final rows = await _readConversationList(tx);
    if (removal.applyTo(rows)) {
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
