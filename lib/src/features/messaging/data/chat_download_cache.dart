import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

/// Best-effort encrypted complete-block cache, never an authorization source.
/// Callers reauthorize before reading and verify the final whole-file digest.
class ChatDownloadCache {
  ChatDownloadCache({required this.root, required this.key});
  final Directory root;
  final SecretKey key;
  static final _cipher = AesGcm.with256bits();
  static final _opens = <String, Future<ChatDownloadCache>>{};

  static Future<String> _hash(String value) async =>
      (await Sha256().hash(utf8.encode(value))).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

  static Future<ChatDownloadCache> open(String account) =>
      _open(account, false);

  static Future<ChatDownloadCache> openSentFiles(String account) =>
      _open(account, true);

  static Future<ChatDownloadCache> _open(String account, bool sent) {
    final scope = jsonEncode([account, sent]);
    return _opens.putIfAbsent(scope, () async {
      try {
        final id = await _hash(account);
        const secure = FlutterSecureStorage();
        final purpose = sent ? 'sent-file' : 'download';
        final name = 'kingclub.chat.$purpose.key.$id';
        final saved = await secure.read(key: name);
        final key = saved == null
            ? await _cipher.newSecretKey()
            : SecretKey(base64Decode(saved));
        if (saved == null) {
          await secure.write(
            key: name,
            value: base64Encode(await key.extractBytes()),
          );
        }
        final parent = await getTemporaryDirectory();
        return ChatDownloadCache(
          root: Directory('${parent.path}/kingclub-$purpose-cache-$id'),
          key: key,
        );
      } catch (_) {
        _opens.remove(scope);
        rethrow;
      }
    });
  }

  Future<Directory> _directory(String identity) async =>
      Directory('${root.path}/${await _hash(identity)}');

  Future<Uint8List?> read(String identity, int index, int length) async {
    try {
      final file = File('${(await _directory(identity)).path}/$index.block');
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file ||
          stat.size != length + 28 ||
          DateTime.now().difference(stat.modified) > const Duration(days: 1)) {
        return null;
      }
      final bytes = await _cipher.decrypt(
        SecretBox.fromConcatenation(
          await file.readAsBytes(),
          nonceLength: 12,
          macLength: 16,
        ),
        secretKey: key,
        aad: utf8.encode('$identity:$index'),
      );
      return bytes.length == length ? Uint8List.fromList(bytes) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String identity, int index, Uint8List bytes) async {
    final directory = await _directory(identity);
    await directory.create(recursive: true);
    final box = await _cipher.encrypt(
      bytes,
      secretKey: key,
      aad: utf8.encode('$identity:$index'),
    );
    final temp = File('${directory.path}/${const Uuid().v4()}.tmp');
    try {
      await temp.writeAsBytes(box.concatenation(), flush: true);
      await temp.rename('${directory.path}/$index.block');
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<void> remove(String identity) async {
    final directory = await _directory(identity);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  /// Keep at most four transfers, expiring abandoned blocks after a day.
  /// Losing an actively used cache entry only causes a network cache miss.
  Future<void> prune(String identity) async {
    await root.create(recursive: true);
    final current = (await _directory(identity)).path;
    final directories = <({Directory directory, DateTime modified})>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory || path.equals(entity.path, current)) continue;
      directories.add((
        directory: entity,
        modified: (await entity.stat()).modified,
      ));
    }
    directories.sort((a, b) => b.modified.compareTo(a.modified));
    for (var i = 0; i < directories.length; i++) {
      if (i >= 3 ||
          DateTime.now().difference(directories[i].modified) >
              const Duration(days: 1)) {
        await directories[i].directory.delete(recursive: true);
      }
    }
  }
}
