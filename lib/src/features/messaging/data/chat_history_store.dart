import 'chat_call_history.dart';
import 'chat_reply.dart';
import 'chat_media_cleanup.dart';
import 'chat_outbox.dart';

import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'chat_location.dart';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

part 'nearby_message_history.dart';
part 'conversation_list_cache.dart';
part 'chat_history_media_cleanup.dart';

class ChatHistoryPage {
  const ChatHistoryPage(
    this.messages,
    this.cursor,
    this.epoch, [
    this.hiddenThrough = 0,
    this.membershipVersion,
    this.presentation,
    this.historyVersion,
  ]);
  final List<Map<String, dynamic>> messages;
  final int cursor, epoch, hiddenThrough;
  final int? membershipVersion;
  final int? historyVersion;
  final Map<String, dynamic>? presentation;
}

/// Message payloads are AES-256-GCM encrypted. Sequence/index metadata is not.
/// No media grants, transport headers or authentication tokens are persisted.
class ChatHistoryStore {
  ChatHistoryStore._(this._db, this._key, this.account, this._outbox);
  final ChatOutbox? _outbox;
  final Database _db;
  int _conversationListRevision = 0;

  /// Fences requests begun before a local conversation was cleared.
  int get conversationListRevision => _conversationListRevision;
  final _clearedConversations =
      StreamController<ConversationHistoryRemoval>.broadcast();
  Stream<ConversationHistoryRemoval> get clearedConversations =>
      _clearedConversations.stream;
  final SecretKey _key;
  final String account;
  static final _cipher = AesGcm.with256bits();
  static final _opens = <String, Future<ChatHistoryStore>>{};

  static Future<ChatHistoryStore> open(String account) {
    if (account.isEmpty) throw ArgumentError('account required');
    return _opens.putIfAbsent(account, () async {
      try {
        final id = await _hash(account);
        const secure = FlutterSecureStorage();
        final saved = await secure.read(key: 'kingclub.chat.history.key.$id');
        final file = path.join(
          await getDatabasesPath(),
          'kingclub-chat-$id.db',
        );
        if (saved == null && await File(file).exists()) {
          throw StateError('History encryption key is unavailable');
        }
        final key = saved == null
            ? await _cipher.newSecretKey()
            : SecretKey(base64Decode(saved));
        if (saved == null) {
          await secure.write(
            key: 'kingclub.chat.history.key.$id',
            value: base64Encode(await key.extractBytes()),
          );
        }
        return await openDatabaseWithKey(
          factory: databaseFactory,
          file: file,
          key: key,
          account: account,
          outbox: SecureChatOutbox(account),
        );
      } catch (_) {
        _opens.remove(account);
        rethrow;
      }
    });
  }

  /// Injection uses the same real SQLite schema and encryption for disk tests.
  static Future<ChatHistoryStore> openDatabaseWithKey({
    required DatabaseFactory factory,
    required String file,
    required SecretKey key,
    required String account,
    ChatOutbox? outbox,
  }) async {
    if ((await key.extractBytes()).length != 32 || account.isEmpty) {
      throw ArgumentError('256-bit account key required');
    }
    final db = await factory.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 16,
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 16) {
            await db.execute(
              'ALTER TABLE message ADD COLUMN stale INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (oldVersion < 15) await _createContactSnapshot(db);
          if (oldVersion >= 6 && oldVersion < 14) {
            await db.execute(
              'ALTER TABLE nearby_message ADD COLUMN readReported INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (oldVersion < 13) await _createConversationListCache(db);
          if (oldVersion < 12) await _createNearbyMembers(db);
          if (oldVersion < 11) await _createNearbyServerPresence(db);
          if (oldVersion < 6) await _createNearbyMessages(db);
          if (oldVersion >= 6 && oldVersion < 7) {
            await db.execute(
              'ALTER TABLE nearby_message ADD COLUMN serverId TEXT',
            );
          }
          if (oldVersion >= 6 && oldVersion < 8) {
            await db.execute(
              'ALTER TABLE nearby_message ADD COLUMN member TEXT',
            );
            await _createNearbyMemberIndex(db);
          }
          if (oldVersion >= 6 && oldVersion < 9) {
            await db.execute(
              'ALTER TABLE nearby_message ADD COLUMN hidden INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (oldVersion >= 6 && oldVersion < 10) {
            await db.execute(
              'ALTER TABLE nearby_message ADD COLUMN wasRead INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE conversation ADD COLUMN hiddenThrough INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (oldVersion < 3) {
            await db.execute(
              'ALTER TABLE conversation ADD COLUMN membershipVersion INTEGER',
            );
          }
          if (oldVersion < 4) {
            await db.execute(
              'ALTER TABLE conversation ADD COLUMN presentation BLOB',
            );
          }
          if (oldVersion < 5) {
            await db.execute(
              'ALTER TABLE conversation ADD COLUMN historyVersion INTEGER',
            );
          }
        },
        onCreate: (db, _) async {
          await _createContactSnapshot(db);
          await _createConversationListCache(db);
          await _createNearbyMembers(db);
          await _createNearbyServerPresence(db);
          await _createNearbyMessages(db);
          await db.execute(
            'CREATE TABLE conversation (id TEXT PRIMARY KEY, cursor INTEGER NOT NULL DEFAULT 0, epoch INTEGER NOT NULL DEFAULT 0, hiddenThrough INTEGER NOT NULL DEFAULT 0, membershipVersion INTEGER, presentation BLOB, historyVersion INTEGER)',
          );
          await db.execute(
            'CREATE TABLE message (conversation TEXT NOT NULL, sequence INTEGER NOT NULL, payload BLOB NOT NULL, stale INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(conversation, sequence))',
          );
        },
      ),
    );
    return ChatHistoryStore._(db, key, account, outbox);
  }

  static Future<void> _createContactSnapshot(Database db) => db.execute(
    'CREATE TABLE contact_snapshot (id INTEGER PRIMARY KEY CHECK(id=1), started INTEGER NOT NULL, payload BLOB NOT NULL)',
  );

  Future<List<Map<String, dynamic>>?> contactSnapshot() async {
    final rows = await _db.query('contact_snapshot');
    if (rows.isEmpty) return null;
    final bytes = await _cipher.decrypt(
      SecretBox.fromConcatenation(
        rows.single['payload'] as List<int>,
        nonceLength: 12,
        macLength: 16,
      ),
      secretKey: _key,
      aad: utf8.encode('contacts:$account:${rows.single['started']}'),
    );
    return (jsonDecode(utf8.decode(bytes)) as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  /// Only a complete successful list may replace the offline snapshot.
  /// The request start orders concurrent refreshes; a late old response loses.
  Future<void> saveContactSnapshot(
    List<Map<String, dynamic>> contacts,
    int started,
  ) async {
    final safe = contacts
        .map(
          (row) => {
            for (final field in ['peer', 'nickname', 'remark', 'bio', 'gender'])
              if (row.containsKey(field)) field: row[field],
          },
        )
        .toList();
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(safe)),
      secretKey: _key,
      aad: utf8.encode('contacts:$account:$started'),
    );
    await _db.rawInsert(
      'INSERT INTO contact_snapshot(id,started,payload) VALUES(1,?,?) ON CONFLICT(id) DO UPDATE SET started=excluded.started,payload=excluded.payload WHERE excluded.started>=contact_snapshot.started',
      [started, box.concatenation()],
    );
  }

  static Future<String> _hash(String value) async =>
      (await Sha256().hash(utf8.encode(value))).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
  Future<String> _conversation(String conversation) =>
      _hash('$account|$conversation');
  List<int> _aad(String conversation, int sequence) =>
      utf8.encode('chat-history-v1|$account|$conversation|$sequence');

  Map<String, dynamic> _payload(Map<String, dynamic> message) {
    const fields = {
      'messageId',
      'conversationId',
      'groupId',
      'clientMessageId',
      'sender',
      'recipient',
      'sequence',
      'text',
      'createdDate',
      'messageType',
      'imageAssetId',
      'fileAssetId',
      'fileName',
      'fileSize',
      'fileSha256',
      'videoAssetId',
      'videoDurationMs',
      'videoWidth',
      'videoHeight',
      'videoHasAudio',
      'voiceAssetId',
      'voiceDurationMs',
      'location',
    };
    final value = {
      for (final key in fields)
        if (message.containsKey(key)) key: message[key],
    };
    if (value['sequence'] is! int ||
        (value['sequence'] as int) < 1 ||
        value['messageId'] is! String ||
        (value['messageId'] as String).isEmpty ||
        value['clientMessageId'] is! String ||
        value['sender'] is! String ||
        value['text'] is! String ||
        (value['text'] as String).length > 4000) {
      throw const FormatException('Invalid confirmed history message');
    }
    // Locations are reduced separately so nested headers/URLs cannot enter disk.
    if (value['messageType'] == 'location') {
      final location = ChatLocation.tryParse(value['location']);
      if (location == null) {
        throw const FormatException('Invalid location history');
      }
      value['location'] = location.toJson();
    } else {
      value.remove('location');
    }
    if (!['hidden', 'recalled'].contains(value['messageType'])) {
      final reply = ChatReply.tryParse(message['reply']);
      if (reply != null) value['reply'] = reply.toJson();
    }
    if (value['groupId'] == null &&
        (value['messageType'] == null || value['messageType'] == 'text')) {
      final call = ChatCallHistory.tryParse(message['call']);
      if (call != null) value['call'] = call.toJson();
    }
    if (utf8.encode(jsonEncode(value)).length > 32768) {
      throw const FormatException('History message exceeds limit');
    }
    return value;
  }

  Future<ChatHistoryPage> read(
    String conversation, {
    int? before,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 200) throw ArgumentError('Invalid page size');
    final id = await _conversation(conversation);
    return _db.transaction((tx) async {
      final state = await tx.query(
        'conversation',
        where: 'id=?',
        whereArgs: [id],
      );
      final rows = await tx.query(
        'message',
        where: before == null
            ? 'conversation=? AND stale=0'
            : 'conversation=? AND stale=0 AND sequence<?',
        whereArgs: [id, ?before],
        orderBy: 'sequence DESC',
        limit: limit,
      );
      final messages = <Map<String, dynamic>>[];
      for (final row in rows.reversed) {
        final plain = await _cipher.decrypt(
          SecretBox.fromConcatenation(
            (row['payload'] as List).cast<int>(),
            nonceLength: 12,
            macLength: 16,
          ),
          secretKey: _key,
          aad: _aad(id, row['sequence'] as int),
        );
        messages.add({
          ...Map<String, dynamic>.from(jsonDecode(utf8.decode(plain)) as Map),
          'status': 'sent',
        });
      }
      Map<String, dynamic>? presentation;
      final encoded = state.isEmpty ? null : state.single['presentation'];
      if (encoded is List) {
        final bytes = await _cipher.decrypt(
          SecretBox.fromConcatenation(
            encoded.cast<int>(),
            nonceLength: 12,
            macLength: 16,
          ),
          secretKey: _key,
          aad: _aad(id, 0),
        );
        presentation = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(bytes)) as Map,
        );
      }
      return ChatHistoryPage(
        messages,
        state.isEmpty ? 0 : state.single['cursor'] as int,
        state.isEmpty ? 0 : state.single['epoch'] as int,
        state.isEmpty ? 0 : state.single['hiddenThrough'] as int,
        state.isEmpty ? null : state.single['membershipVersion'] as int?,
        presentation,
        state.isEmpty ? null : state.single['historyVersion'] as int?,
      );
    });
  }

  /// Atomic pages and checkpoint; expected epoch rejects pre-clear responses.
  Future<bool> commit(
    String conversation,
    List<Map<String, dynamic>> messages, {
    required int expectedEpoch,
    int? cursor,
    int hiddenThrough = 0,
    int? membershipVersion,
    int? historyVersion,
    int? peerReadSequence,
    String? serverConversationId,
    ChatMediaCleanup? mediaCleanup,
  }) async {
    if ((peerReadSequence == null) != (serverConversationId == null) ||
        (peerReadSequence != null &&
            (!conversation.startsWith('direct:') ||
                peerReadSequence < 0 ||
                serverConversationId!.isEmpty ||
                serverConversationId.length > 128))) {
      throw ArgumentError('Invalid direct read receipt');
    }
    if ((historyVersion != null &&
            (historyVersion < 0 || historyVersion > 4294967295)) ||
        (membershipVersion != null && membershipVersion < 0) ||
        expectedEpoch < 0 ||
        hiddenThrough < 0 ||
        (cursor != null && cursor < 0)) {
      throw ArgumentError('Invalid history cursor');
    }
    final id = await _conversation(conversation);
    final rows = <Map<String, Object?>>[];
    for (final message in messages) {
      final value = _payload(message);
      final sequence = value['sequence'] as int;
      final encrypted = await _cipher.encrypt(
        utf8.encode(jsonEncode(value)),
        secretKey: _key,
        aad: _aad(id, sequence),
      );
      rows.add({
        'conversation': id,
        'sequence': sequence,
        'payload': encrypted.concatenation(),
      });
    }
    ConversationHistoryRemoval? removal;
    final committed = await _db.transaction((tx) async {
      await tx.insert('conversation', {
        'id': id,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final state = (await tx.query(
        'conversation',
        where: 'id=?',
        whereArgs: [id],
      )).single;
      if (state['epoch'] != expectedEpoch) return false;
      if (state['historyVersion'] != historyVersion) return false;
      final savedVersion = state['membershipVersion'] as int?;
      if (savedVersion != null &&
          (membershipVersion == null || membershipVersion < savedVersion)) {
        return false;
      }
      final savedHidden = state['hiddenThrough'] as int;
      final floor = hiddenThrough > savedHidden ? hiddenThrough : savedHidden;
      final removedSequences = await _cleanupSupersededMedia(
        tx,
        conversation,
        id,
        messages,
        floor,
        mediaCleanup ?? ChatMediaCleanup(),
      );
      if (removedSequences.isNotEmpty || floor > savedHidden) {
        removal = ConversationHistoryRemoval(
          conversation,
          sequences: removedSequences,
          hiddenThrough: floor,
        );
        _conversationListRevision++;
        await _removeConversationListEntry(tx, removal!);
      }
      final batch = tx.batch();
      if (peerReadSequence != null) {
        var readSequence = peerReadSequence;
        final encoded = state['presentation'];
        if (encoded is List) {
          final bytes = await _cipher.decrypt(
            SecretBox.fromConcatenation(
              encoded.cast<int>(),
              nonceLength: 12,
              macLength: 16,
            ),
            secretKey: _key,
            aad: _aad(id, 0),
          );
          final saved = jsonDecode(utf8.decode(bytes)) as Map;
          final priorRead = saved['peerReadSequence'];
          if (saved['conversationId'] == serverConversationId &&
              priorRead is int &&
              priorRead > readSequence) {
            readSequence = priorRead;
          }
        }
        final box = await _cipher.encrypt(
          utf8.encode(
            jsonEncode({
              'conversationId': serverConversationId,
              'peerReadSequence': readSequence,
            }),
          ),
          secretKey: _key,
          aad: _aad(id, 0),
        );
        batch.update(
          'conversation',
          {'presentation': box.concatenation()},
          where: 'id=?',
          whereArgs: [id],
        );
      }
      batch.delete(
        'message',
        where: 'conversation=? AND sequence<=?',
        whereArgs: [id, floor],
      );
      batch.update(
        'conversation',
        {
          'hiddenThrough': floor,
          'membershipVersion': ?membershipVersion,
          if (savedVersion != membershipVersion) 'presentation': null,
        },
        where: 'id=?',
        whereArgs: [id],
      );
      for (final row in rows) {
        if ((row['sequence'] as int) <= floor) continue;
        batch.insert(
          'message',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (cursor != null && cursor > (state['cursor'] as int)) {
        batch.update(
          'conversation',
          {'cursor': cursor},
          where: 'id=?',
          whereArgs: [id],
        );
      }
      await batch.commit(noResult: true);
      if (conversation.startsWith('direct:')) {
        await _reconcileNearbyRows(
          tx,
          'member',
          id,
          conversation.substring('direct:'.length),
          messages,
        );
      }
      return true;
    });
    if (committed && removal != null) _clearedConversations.add(removal!);
    return committed;
  }

  /// A presentation snapshot has no authority to allow sending or media reads.
  Future<bool> saveGroupPresentation(
    String conversation, {
    required int expectedEpoch,
    required int membershipVersion,
    required String groupName,
    required Map<String, String> memberNames,
  }) async {
    if (groupName.length > 100 ||
        memberNames.length > 200 ||
        expectedEpoch < 0 ||
        membershipVersion < 0 ||
        memberNames.entries.any(
          (entry) =>
              entry.key.isEmpty ||
              entry.key.length > 64 ||
              entry.value.length > 100,
        )) {
      throw const FormatException('Invalid group presentation');
    }
    final id = await _conversation(conversation);
    final box = await _cipher.encrypt(
      utf8.encode(
        jsonEncode({'groupName': groupName, 'memberNames': memberNames}),
      ),
      secretKey: _key,
      aad: _aad(id, 0),
    );
    return await _db.update(
          'conversation',
          {'presentation': box.concatenation()},
          where: 'id=? AND epoch=? AND membershipVersion=?',
          whereArgs: [id, expectedEpoch, membershipVersion],
        ) ==
        1;
  }

  /// Accept a server revision before merging a page. A changed revision removes
  /// all cached pages and advances the epoch, rejecting older in-flight writes.
  /// The outgoing queue is separate and is never removed here.
  Future<int?> adoptHistoryVersion(
    String conversation, {
    required int expectedEpoch,
    required int historyVersion,
  }) async {
    if (expectedEpoch < 0 ||
        historyVersion < 0 ||
        historyVersion > 4294967295) {
      throw ArgumentError('Invalid history revision');
    }
    final id = await _conversation(conversation);
    return _db.transaction((tx) async {
      await tx.insert('conversation', {
        'id': id,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final state = (await tx.query(
        'conversation',
        where: 'id=?',
        whereArgs: [id],
      )).single;
      if (state['epoch'] != expectedEpoch) return null;
      final saved = state['historyVersion'] as int?;
      if (saved != null && historyVersion < saved) return null;
      if (saved == historyVersion) return expectedEpoch;
      await tx.update(
        'message',
        {'stale': 1},
        where: 'conversation=?',
        whereArgs: [id],
      );
      final epoch = expectedEpoch + 1;
      await tx.update(
        'conversation',
        {'cursor': 0, 'epoch': epoch, 'historyVersion': historyVersion},
        where: 'id=?',
        whereArgs: [id],
      );
      return epoch;
    });
  }

  Future<int> clear(
    String conversation, {
    bool hideNearby = false,
    ChatMediaCleanup? mediaCleanup,
    bool deleteMedia = true,
    Set<String>? deletedMessageIds,
  }) async {
    if (hideNearby && !conversation.startsWith('direct:')) {
      throw ArgumentError('Nearby history requires a direct conversation');
    }
    if (deletedMessageIds != null && !deleteMedia) {
      throw ArgumentError('Targeted deletion requires media cleanup');
    }
    final pending = deleteMedia
        ? await _outbox?.read() ?? <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[];
    final id = await _conversation(conversation);
    ConversationHistoryRemoval? removal;
    final nextEpoch = await _db.transaction((tx) async {
      await tx.insert('conversation', {
        'id': id,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final epoch =
          (await tx.query(
                'conversation',
                where: 'id=?',
                whereArgs: [id],
              )).single['epoch']
              as int;
      // Delete owned media before discarding the encrypted metadata needed to
      // locate it. A filesystem failure leaves history available for retry.
      final deletedSequences = <int>[];
      if (deleteMedia) {
        final cleanup = mediaCleanup ?? ChatMediaCleanup();
        final retainedVoiceAssets = <String>{};
        final retainedFileAssets = <String>{};
        final retainedSentClients = <String>{};
        for (final message in pending) {
          if (message['sender'] != account) continue;
          final voice = message['voiceAssetId'],
              file = message['fileAssetId'],
              client = message['clientMessageId'];
          if (voice is String) retainedVoiceAssets.add(voice);
          if (file is String) retainedFileAssets.add(file);
          if (client is String) retainedSentClients.add(client);
        }
        // Payloads are encrypted; inspect remaining conversations in bounded
        // batches before discarding any shared asset. The transaction prevents
        // a concurrent history write from changing this reference snapshot.
        var referenceOffset = 0;
        while (true) {
          final references = await tx.query(
            'message',
            orderBy: 'conversation, sequence',
            limit: 50,
            offset: referenceOffset,
          );
          for (final row in references) {
            final plain = await _cipher.decrypt(
              SecretBox.fromConcatenation(
                (row['payload'] as List).cast<int>(),
                nonceLength: 12,
                macLength: 16,
              ),
              secretKey: _key,
              aad: _aad(row['conversation'] as String, row['sequence'] as int),
            );
            final message = jsonDecode(utf8.decode(plain)) as Map;
            if (row['conversation'] == id &&
                (deletedMessageIds == null ||
                    deletedMessageIds.contains(message['messageId']))) {
              continue;
            }
            final asset = message['voiceAssetId'];
            if (asset is String && message['messageType'] == 'voice') {
              retainedVoiceAssets.add(asset);
            }
            final fileAsset = message['fileAssetId'];
            if (fileAsset is String && message['messageType'] == 'file') {
              retainedFileAssets.add(fileAsset);
            }
            final client = message['clientMessageId'];
            if (message['sender'] == account && client is String) {
              retainedSentClients.add(client);
            }
          }
          if (references.length < 50) break;
          referenceOffset += references.length;
        }
        var offset = 0;
        while (true) {
          final rows = await tx.query(
            'message',
            where: 'conversation=?',
            whereArgs: [id],
            orderBy: 'sequence ASC',
            limit: 50,
            offset: offset,
          );
          for (final row in rows) {
            final plain = await _cipher.decrypt(
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
            if (deletedMessageIds != null &&
                !deletedMessageIds.contains(message['messageId'])) {
              continue;
            }
            await cleanup.remove(
              account: account,
              group: conversation.startsWith('group:'),
              retainedVoiceAssets: retainedVoiceAssets,
              retainedFileAssets: retainedFileAssets,
              retainedSentClients: retainedSentClients,
              message: message,
            );
            if (deletedMessageIds != null) {
              deletedSequences.add(row['sequence'] as int);
            }
          }
          if (rows.length < 50) break;
          offset += rows.length;
        }
      }
      if (deletedMessageIds == null) {
        if (deleteMedia) {
          await tx.delete('message', where: 'conversation=?', whereArgs: [id]);
        } else {
          await tx.update(
            'message',
            {'stale': 1},
            where: 'conversation=?',
            whereArgs: [id],
          );
        }
      } else {
        final batch = tx.batch();
        for (final sequence in deletedSequences) {
          batch.delete(
            'message',
            where: 'conversation=? AND sequence=?',
            whereArgs: [id, sequence],
          );
        }
        await batch.commit(noResult: true);
      }
      if (hideNearby) {
        await tx.update(
          'nearby_message',
          {'hidden': 1},
          where: 'member=?',
          whereArgs: [id],
        );
      }
      if (deleteMedia &&
          (deletedMessageIds == null || deletedSequences.isNotEmpty)) {
        removal = ConversationHistoryRemoval(
          conversation,
          sequences: deletedMessageIds == null
              ? null
              : deletedSequences.toSet(),
        );
        _conversationListRevision++;
        await _removeConversationListEntry(tx, removal!);
      }
      await tx.update(
        'conversation',
        {'cursor': 0, 'epoch': epoch + 1, 'presentation': null},
        where: 'id=?',
        whereArgs: [id],
      );
      return epoch + 1;
    });
    if (removal != null) {
      _clearedConversations.add(removal!);
    }
    return nextEpoch;
  }

  Future<void> close() async {
    _opens.remove(account);
    await _db.close();
    await _clearedConversations.close();
  }
}
