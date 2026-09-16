part of 'chat_history_store.dart';

extension _HistoryMediaCleanup on ChatHistoryStore {
  Future<Set<int>> _cleanupSupersededMedia(
    Transaction tx,
    String conversation,
    String id,
    List<Map<String, dynamic>> incoming,
    int floor,
    ChatMediaCleanup cleanup,
  ) async {
    final tombstones = {
      for (final message in incoming)
        if (const {'hidden', 'recalled'}.contains(message['messageType']))
          message['sequence'] as int,
    };
    if (floor == 0 && tombstones.isEmpty) return {};
    final condition = tombstones.isEmpty
        ? 'sequence<=?'
        : '(sequence<=? OR sequence IN (${List.filled(tombstones.length, '?').join(',')}))';
    if ((await tx.query(
      'message',
      columns: ['sequence'],
      where: 'conversation=? AND $condition',
      whereArgs: [id, floor, ...tombstones],
      limit: 1,
    )).isEmpty) {
      return {};
    }

    final removed = <Map<String, dynamic>>[];
    final removedContent = <int>{};
    final voices = <String>{}, files = <String>{}, clients = <String>{};
    void retain(Map message) {
      final voice = message['voiceAssetId'],
          file = message['fileAssetId'],
          client = message['clientMessageId'];
      if (voice is String) voices.add(voice);
      if (file is String) files.add(file);
      if (message['sender'] == account && client is String) clients.add(client);
    }

    final replaced = incoming.map((row) => row['sequence']).toSet();
    var offset = 0;
    while (true) {
      final rows = await tx.query(
        'message',
        orderBy: 'conversation, sequence',
        limit: 50,
        offset: offset,
      );
      for (final row in rows) {
        final plain = await ChatHistoryStore._cipher.decrypt(
          SecretBox.fromConcatenation(
            (row['payload'] as List).cast<int>(),
            nonceLength: 12,
            macLength: 16,
          ),
          secretKey: _key,
          aad: _aad(row['conversation'] as String, row['sequence'] as int),
        );
        final message = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(plain)) as Map,
        );
        final target = row['conversation'] == id;
        final sequence = row['sequence'] as int;
        if (target && (sequence <= floor || tombstones.contains(sequence))) {
          if (!const {'hidden', 'recalled'}.contains(message['messageType'])) {
            removedContent.add(sequence);
          }
          if (const {
            'image',
            'video',
            'voice',
            'file',
          }.contains(message['messageType'])) {
            removed.add(message);
          }
        } else if (!target || !replaced.contains(sequence)) {
          retain(message);
        }
      }
      if (rows.length < 50) break;
      offset += rows.length;
    }
    if (removed.isEmpty) return removedContent;
    for (final message in incoming) {
      if ((message['sequence'] as int) > floor &&
          !const {'hidden', 'recalled'}.contains(message['messageType'])) {
        retain(message);
      }
    }
    for (final message in await _outbox?.read() ?? <Map<String, dynamic>>[]) {
      if (message['sender'] == account) retain(message);
    }
    for (final message in removed) {
      await cleanup.remove(
        account: account,
        group: conversation.startsWith('group:'),
        message: message,
        retainedVoiceAssets: voices,
        retainedFileAssets: files,
        retainedSentClients: clients,
      );
    }
    return removedContent;
  }
}
