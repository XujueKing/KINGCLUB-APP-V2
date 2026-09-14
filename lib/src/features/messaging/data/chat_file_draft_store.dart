import 'dart:convert';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ChatFileDraft {
  const ChatFileDraft(this.id, this.file, this.name, this.size, this.sha256);
  final String id, name, sha256;
  final File file;
  final int size;
}

class ChatFileDraftStore {
  ChatFileDraftStore({
    required this.account,
    required this.target,
    required this.checkSession,
    FlutterSecureStorage? storage,
    Future<Directory> Function()? directory,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _directory = directory ?? getApplicationSupportDirectory;
  final String account, target;
  final Future<void> Function() checkSession;
  final FlutterSecureStorage _storage;
  final Future<Directory> Function() _directory;
  static final _locks = <String, Future<void>>{};
  String get _key =>
      'kingclub.file-draft.${base64UrlEncode(utf8.encode(jsonEncode([account, target])))}';
  Future<T> _exclusive<T>(Future<T> Function() work) async {
    final key = _key;
    final result = (_locks[key] ?? Future<void>.value()).then((_) => work());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _locks[key] = tail;
    try {
      return await result;
    } finally {
      if (identical(_locks[key], tail)) _locks.remove(key);
    }
  }

  String _hex(List<int> value) =>
      value.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  Future<Directory> _root() async {
    final hash = _hex(
      (await const DartSha256().hash(
        utf8.encode(jsonEncode([account, target])),
      )).bytes,
    );
    return Directory('${(await _directory()).path}/chat-file-drafts/$hash')
        .create(recursive: true);
  }

  Future<ChatFileDraft?> _read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map;
    final id = data['id'];
    if (id is! String || !RegExp(r'^[0-9a-f-]{36}$').hasMatch(id)) {
      throw const FormatException('Invalid draft');
    }
    return ChatFileDraft(
      id,
      File('${(await _root()).path}/$id.bin'),
      data['name'] as String,
      data['size'] as int,
      data['sha256'] as String,
    );
  }

  Future<String> _digest(File source, int size) async {
    final hash = const DartSha256().newHashSink();
    var total = 0;
    await for (final bytes in source.openRead()) {
      await checkSession();
      total += bytes.length;
      if (total > size) throw StateError('Draft changed');
      hash.add(bytes);
    }
    hash.close();
    if (total != size) throw StateError('Draft changed');
    return _hex((await hash.hash()).bytes);
  }

  Future<ChatFileDraft?> read() => _exclusive(() async {
    await checkSession();
    final draft = await _read();
    if (draft != null &&
        (draft.size < 0 ||
            draft.size > 268435456 ||
            await _digest(draft.file, draft.size) != draft.sha256)) {
      throw StateError('Draft damaged');
    }
    await checkSession();
    return draft;
  });
  Future<ChatFileDraft> save(File source, String name) => _exclusive(() async {
    await checkSession();
    final size = await source.length();
    if (size > 268435456 || name.isEmpty || name.length > 180) {
      throw ArgumentError('Invalid draft');
    }
    final previous = await _storage.read(key: _key);
    final id = const Uuid().v4();
    final file = File('${(await _root()).path}/$id.bin');
    RandomAccessFile? output;
    var committed = false, publicationAttempted = false;
    try {
      output = await file.open(mode: FileMode.write);
      final hash = const DartSha256().newHashSink();
      var total = 0;
      await for (final bytes in source.openRead()) {
        await checkSession();
        total += bytes.length;
        if (total > size) throw StateError('Source changed');
        hash.add(bytes);
        await output.writeFrom(bytes);
      }
      hash.close();
      if (total != size) throw StateError('Source changed');
      await output.flush();
      await output.close();
      output = null;
      final digest = _hex((await hash.hash()).bytes);
      await checkSession();
      publicationAttempted = true;
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'id': id,
          'name': name,
          'size': size,
          'sha256': digest,
        }),
      );
      committed = true;
      try {
        await checkSession();
      } catch (_) {
        if (previous == null) {
          await _storage.delete(key: _key);
        } else {
          await _storage.write(key: _key, value: previous);
        }
        committed = false;
        publicationAttempted = false;
        rethrow;
      }
      if (previous != null) {
        try {
          final oldId = (jsonDecode(previous) as Map)['id'];
          if (oldId is String &&
              RegExp(r'^[0-9a-f-]{36}$').hasMatch(oldId) &&
              oldId != id) {
            final oldFile = File('${file.parent.path}/$oldId.bin');
            if (await oldFile.exists()) await oldFile.delete();
          }
        } catch (_) {
          /* New durable selection remains usable if old cleanup fails. */
        }
      }
      return ChatFileDraft(id, file, name, size, digest);
    } finally {
      try {
        await output?.close();
      } finally {
        if (!committed && !publicationAttempted && await file.exists()) {
          await file.delete();
        }
      }
    }
  });
  Future<void> remove(String id) => _exclusive(() async {
    await checkSession();
    final draft = await _read();
    if (draft?.id != id) return;
    await _storage.delete(key: _key);
    if (await draft!.file.exists()) await draft.file.delete();
  });
}
