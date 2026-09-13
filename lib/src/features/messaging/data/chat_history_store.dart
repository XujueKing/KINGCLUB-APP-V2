import 'dart:convert';
import 'dart:io';

import 'chat_location.dart';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class ChatHistoryPage {
  const ChatHistoryPage(this.messages, this.cursor, this.epoch);
  final List<Map<String, dynamic>> messages;
  final int cursor, epoch;
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
        version: 2,
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE conversation ADD COLUMN hiddenThrough INTEGER NOT NULL DEFAULT 0',
            );
          }
        },
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE conversation (id TEXT PRIMARY KEY, cursor INTEGER NOT NULL DEFAULT 0, epoch INTEGER NOT NULL DEFAULT 0, hiddenThrough INTEGER NOT NULL DEFAULT 0)',
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
      return ChatHistoryPage(
        messages,
        state.isEmpty ? 0 : state.single['cursor'] as int,
        state.isEmpty ? 0 : state.single['epoch'] as int,
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
  }) async {
    if (expectedEpoch < 0 ||
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
        {'hiddenThrough': floor},
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
      return true;
    });
  }

  Future<int> clear(String conversation) async {
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
      await tx.update(
        'conversation',
        {'cursor': 0, 'epoch': epoch + 1},
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
