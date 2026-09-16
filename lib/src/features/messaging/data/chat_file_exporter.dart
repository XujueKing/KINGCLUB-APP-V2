import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/session/secure_session_store.dart';
import 'chat_file_downloader.dart';
import 'chat_media_deletion.dart';

class ChatFileExporter {
  ChatFileExporter({String? account}) {
    _session = SecureSessionStore.changes.stream.listen((_) => dispose());
    _removeDeletionListener = ChatMediaDeletion.listen((event) async {
      final reference = _reference;
      if (account != null &&
          event.account == account &&
          event.group == reference?.group &&
          event.messageId == reference?.messageId) {
        await dispose();
      }
    });
  }
  static const channel = MethodChannel('kingclub/chat-file-export');
  late final StreamSubscription<void> _session;
  late final void Function() _removeDeletionListener;
  ChatFileReference? _reference;
  String? _operationId;
  String? _savedOperationId;
  bool _disposed = false, _busy = false;
  Future<bool> save(
    File file,
    ChatFileReference reference,
    Future<void> Function() authorize,
  ) async {
    if (_disposed || _busy) throw StateError('Export unavailable');
    _busy = true;
    _reference = reference;
    final operationId = const Uuid().v4();
    _operationId = operationId;
    var saved = false;
    try {
      await authorize();
      if (_disposed) return false;
      final chosen = await channel.invokeMethod<bool>('choose', {
        'name': reference.fileName,
        'operationId': operationId,
      });
      if (chosen != true || _disposed) return false;
      await authorize();
      if (_disposed) return false;
      saved =
          await channel.invokeMethod<bool>('copy', {
            'operationId': operationId,
            'path': file.path,
            'size': reference.size,
            'sha256': reference.sha256,
          }) ==
          true;
      if (saved && !_disposed) _savedOperationId = operationId;
      return saved && !_disposed;
    } finally {
      try {
        if (!saved) {
          await channel.invokeMethod<void>('cancel', {
            'operationId': operationId,
          });
        }
      } finally {
        _operationId = null;
        _busy = false;
      }
    }
  }

  Future<bool> openSaved() async {
    final id = _savedOperationId;
    if (_disposed || _busy || id == null) return false;
    _busy = true;
    try {
      return await channel.invokeMethod<bool>('openSaved', {
            'operationId': id,
          }) ==
          true;
    } finally {
      _busy = false;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _removeDeletionListener();
    await _session.cancel();
    try {
      final id = _operationId;
      if (id != null) {
        await channel.invokeMethod<void>('cancel', {'operationId': id});
      }
      final savedId = _savedOperationId;
      _savedOperationId = null;
      if (savedId != null) {
        await channel.invokeMethod<void>('cancel', {'operationId': savedId});
      }
    } catch (_) {}
  }
}
