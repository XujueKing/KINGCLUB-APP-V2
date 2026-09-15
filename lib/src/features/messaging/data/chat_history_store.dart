import 'chat_call_history.dart';
import 'chat_reply.dart';

import 'dart:convert';
import 'dart:io';

import 'chat_location.dart';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

part 'nearby_message_history.dart';

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
  ChatHistoryStore._(this._db, this._key, this.account);
  final Database _db;
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
  }) async {
    if ((await key.extractBytes()).length != 32 || account.isEmpty) {
      throw ArgumentError('256-bit account key required');
    }
    final db = await factory.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 10,
        onUpgrade: (db, oldVersion, _) async {
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
          await _createNearbyMessages(db);
          await db.execute(
            'CREATE TABLE conversation (id TEXT PRIMARY KEY, cursor INTEGER NOT NULL DEFAULT 0, epoch INTEGER NOT NULL DEFAULT 0, hiddenThrough INTEGER NOT NULL DEFAULT 0, membershipVersion INTEGER, presentation BLOB, historyVersion INTEGER)',
          );
          await db.execute(
            'CREATE TABLE message (conversation TEXT NOT NULL, sequence INTEGER NOT NULL, payload BLOB NOT NULL, PRIMARY KEY(conversation, sequence))',
          );
        },
      ),
    );
    return ChatHistoryStore._(db, key, account);
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
            ? 'conversation=?'
            : 'conversation=? AND sequence<?',
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
  }) async {
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
    return _db.transaction((tx) async {
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
      final batch = tx.batch();
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
      await tx.delete('message', where: 'conversation=?', whereArgs: [id]);
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

  Future<int> clear(String conversation, {bool hideNearby = false}) async {
    if (hideNearby && !conversation.startsWith('direct:')) {
      throw ArgumentError('Nearby history requires a direct conversation');
    }
    final id = await _conversation(conversation);
    return _db.transaction((tx) async {
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
      await tx.delete('message', where: 'conversation=?', whereArgs: [id]);
      if (hideNearby) {
        await tx.update(
          'nearby_message',
          {'hidden': 1},
          where: 'member=?',
          whereArgs: [id],
        );
      }
      await tx.update(
        'conversation',
        {'cursor': 0, 'epoch': epoch + 1, 'presentation': null},
        where: 'id=?',
        whereArgs: [id],
      );
      return epoch + 1;
    });
  }

  Future<void> close() async {
    _opens.remove(account);
    await _db.close();
  }
}
