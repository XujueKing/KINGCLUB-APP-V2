import 'dart:io';
import 'dart:isolate';

import 'canonical_voice_container.dart';

/// Owns temporary sanitized copies, never edits a gallery file or a draft.
class ChatVideoCanonicalSource {
  Directory? _directory;
  bool _closed = false;
  int _next = 0;
  Future<File> prepare(File source) async {
    if (_closed) throw StateError('视频处理已取消');
    final length = await source.length();
    if (length < 16 || length > 32 * 1024 * 1024) return source;
    final directory = _directory ??= await Directory.systemTemp.createTemp(
      'kingclub-video-canonical-',
    );
    final path = source.path, output = '${directory.path}/${_next++}.mp4';
    try {
      final changed = await Isolate.run(() async {
        final bytes = await File(path).readAsBytes();
        final canonical = canonicalVideoContainer(bytes);
        if (canonical == null) return false;
        var equal = true;
        for (var i = 0; i < bytes.length; i++) {
          if (bytes[i] != canonical[i]) {
            equal = false;
            break;
          }
        }
        if (equal) return false;
        await File(output).writeAsBytes(canonical, flush: true);
        return true;
      });
      if (_closed) throw StateError('视频处理已取消');
      return changed ? File(output) : source;
    } finally {
      if (_closed) await _cleanup();
    }
  }

  Future<void> _cleanup() async {
    final directory = _directory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> close() async {
    _closed = true;
    await _cleanup();
  }
}
