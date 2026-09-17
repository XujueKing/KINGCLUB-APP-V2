part of 'chat_history_store.dart';

Future<void> _createDeferredMediaCleanup(Database db) => db.execute(
  'CREATE TABLE IF NOT EXISTS deferred_media_cleanup (id TEXT PRIMARY KEY, payload BLOB NOT NULL)',
);

extension ChatHistoryDeferredCleanup on ChatHistoryStore {
  bool _sharedMediaRetained(
    Map message,
    Set<String> voices,
    Set<String> files,
    Set<String> clients,
  ) =>
      (message['messageType'] == 'voice' &&
          voices.contains(message['voiceAssetId'])) ||
      (message['messageType'] == 'file' &&
          files.contains(message['fileAssetId'])) ||
      (const {'image', 'video'}.contains(message['messageType']) &&
          message['sender'] == account &&
          clients.contains(message['clientMessageId']));

  Future<void> _deferSharedMedia(
    Transaction tx,
    Map<String, dynamic> message, {
    required Set<String> voices,
    required Set<String> files,
    required Set<String> clients,
  }) async {
    if (!_sharedMediaRetained(message, voices, files, clients)) return;
    // Store only the source locator, never deleted text, replies, names,
    // message IDs or bearer grants. Without a message ID the cleanup operates
    // exclusively on shared source copies and cannot redispatch deletion UI.
    final locator = <String, dynamic>{
      for (final key in const [
        'messageType',
        'sender',
        'clientMessageId',
        'voiceAssetId',
        'fileAssetId',
        'fileSize',
        'fileSha256',
      ])
        if (message[key] != null) key: message[key],
    };
    final bytes = utf8.encode(jsonEncode(locator));
    final id = await ChatHistoryStore._hash(jsonEncode(locator));
    final box = await ChatHistoryStore._cipher.encrypt(
      bytes,
      secretKey: _key,
      aad: utf8.encode('deferred-media:$account:$id'),
    );
    await tx.insert('deferred_media_cleanup', {
      'id': id,
      'payload': box.concatenation(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> collectDeferredMedia({ChatMediaCleanup? mediaCleanup}) =>
      _protectPendingReferences((readPending) async {
        if (_closed) return;
        await _collectDeferredMedia(
          readPending,
          mediaCleanup ?? ChatMediaCleanup(),
        );
      });

  Future<void> _collectDeferredMedia(
    PendingMessageReader readPending,
    ChatMediaCleanup cleanup,
  ) async {
    if (_closed) return;
    await _db.transaction((tx) async {
      if ((await tx.query(
        'deferred_media_cleanup',
        columns: ['id'],
        limit: 1,
      )).isEmpty) {
        return;
      }
      final voices = <String>{}, files = <String>{}, clients = <String>{};
      void retain(Map message) {
        final voice = message['voiceAssetId'],
            file = message['fileAssetId'],
            client = message['clientMessageId'];
        if (voice is String) voices.add(voice);
        if (file is String) files.add(file);
        if (message['sender'] == account && client is String) {
          clients.add(client);
        }
      }

      for (final message in await readPending()) {
        if (message['sender'] == account) retain(message);
      }
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
          retain(jsonDecode(utf8.decode(plain)) as Map);
        }
        if (rows.length < 50) break;
        offset += rows.length;
      }
      String? after;
      while (true) {
        final rows = await tx.query(
          'deferred_media_cleanup',
          where: after == null ? null : 'id>?',
          whereArgs: after == null ? null : [after],
          orderBy: 'id',
          limit: 50,
        );
        for (final row in rows) {
          final id = row['id'] as String;
          final plain = await ChatHistoryStore._cipher.decrypt(
            SecretBox.fromConcatenation(
              (row['payload'] as List).cast<int>(),
              nonceLength: 12,
              macLength: 16,
            ),
            secretKey: _key,
            aad: utf8.encode('deferred-media:$account:$id'),
          );
          final locator = Map<String, dynamic>.from(
            jsonDecode(utf8.decode(plain)) as Map,
          );
          if (!_sharedMediaRetained(locator, voices, files, clients)) {
            await cleanup.remove(
              account: account,
              group: false,
              message: locator,
              retainedVoiceAssets: voices,
              retainedFileAssets: files,
              retainedSentClients: clients,
            );
            await tx.delete(
              'deferred_media_cleanup',
              where: 'id=?',
              whereArgs: [id],
            );
          }
          after = id;
        }
        if (rows.length < 50) break;
      }
    });
  }
}
