import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cryptography/dart.dart';
import 'package:path_provider/path_provider.dart';

import 'chat_download_cache.dart';

/// Opportunistic source bytes only. Never establishes permission to send.
class ChatSentFileCache {
  ChatSentFileCache({
    required this.cache,
    required this.checkSession,
    Future<Directory> Function()? temporaryDirectory,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final ChatDownloadCache cache;
  final Future<void> Function() checkSession;
  final Future<Directory> Function() _temporaryDirectory;
  static const maxBytes = 64 * 1024 * 1024;
  static const chunkBytes = 1024 * 1024;
  static final _locks = <String, Future<void>>{};

  Future<T> _exclusive<T>(Future<T> Function() work) async {
    final key = cache.root.absolute.path;
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

  String _identity(String assetId, int size, String sha256) {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(assetId) ||
        size < 0 ||
        size > maxBytes ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw ArgumentError('Invalid retained file');
    }
    return jsonEncode(['sent-file-v1', assetId, size, sha256]);
  }

  String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  /// Release the final local history reference after any active retain/use.
  /// A later new authorized message may retain the same asset again.
  Future<void> remove({
    required String assetId,
    required int size,
    required String sha256,
  }) => _exclusive(() async {
    if (size > maxBytes) return;
    await cache.remove(_identity(assetId, size, sha256));
  });

  Future<bool> retain(
    File source, {
    required String assetId,
    required int size,
    required String sha256,
  }) => _exclusive(() async {
    await checkSession();
    if (size > maxBytes) return false;
    final identity = _identity(assetId, size, sha256);
    await cache.prune(identity);
    RandomAccessFile? reader;
    var complete = false;
    try {
      if (await source.length() != size) throw StateError('Source changed');
      reader = await source.open();
      final hash = const DartSha256().newHashSink();
      final count = math.max(1, (size + chunkBytes - 1) ~/ chunkBytes);
      for (var index = 0; index < count; index++) {
        await checkSession();
        final length = math.min(chunkBytes, size - index * chunkBytes);
        final bytes = await reader.read(length);
        if (bytes.length != length) throw StateError('Source changed');
        hash.add(bytes);
        await cache.write(identity, index, bytes);
      }
      hash.close();
      if (_hex((await hash.hash()).bytes) != sha256 ||
          (await reader.read(1)).isNotEmpty) {
        throw StateError('Source changed');
      }
      await checkSession();
      complete = true;
      return true;
    } finally {
      try {
        await reader?.close();
      } finally {
        if (!complete) await cache.remove(identity);
      }
    }
  });

  /// The callback must independently authorize the recipient and message.
  /// No caller may retain this temporary file beyond the callback.
  Future<T?> use<T>({
    required String assetId,
    required int size,
    required String sha256,
    required Future<T> Function(File source) send,
  }) async {
    await checkSession();
    if (size > maxBytes) return null;
    final identity = _identity(assetId, size, sha256);
    final directory = await (await _temporaryDirectory()).createTemp(
      'kingclub-peer-source-',
    );
    try {
      final source = File('${directory.path}/content.bin');
      final ready = await _exclusive(() async {
        await checkSession();
        final output = await source.open(mode: FileMode.write);
        try {
          final hash = const DartSha256().newHashSink();
          final count = math.max(1, (size + chunkBytes - 1) ~/ chunkBytes);
          for (var index = 0; index < count; index++) {
            await checkSession();
            final length = math.min(chunkBytes, size - index * chunkBytes);
            final bytes = await cache.read(identity, index, length);
            if (bytes == null) return false;
            hash.add(bytes);
            await output.writeFrom(bytes);
          }
          hash.close();
          if (_hex((await hash.hash()).bytes) != sha256) return false;
          await output.flush();
          await checkSession();
          return true;
        } finally {
          await output.close();
        }
      });
      if (!ready) return null;
      await checkSession();
      final result = await send(source);
      await checkSession();
      return result;
    } finally {
      await directory.delete(recursive: true);
    }
  }
}
