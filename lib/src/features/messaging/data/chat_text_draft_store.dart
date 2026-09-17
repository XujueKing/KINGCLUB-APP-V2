import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'chat_file_draft_store.dart';

class ChatTextDraft {
  ChatTextDraft(this.text, {this.replyTo, this.preview, String? id})
    : id = id ?? const Uuid().v4();
  final String id, text;
  final String? replyTo, preview;
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'replyTo': replyTo,
    'preview': preview,
  };
  static ChatTextDraft parse(String raw) {
    final value = jsonDecode(raw) as Map;
    final id = value['id'],
        text = value['text'],
        reply = value['replyTo'],
        preview = value['preview'];
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (id is! String ||
        !uuid.hasMatch(id) ||
        text is! String ||
        text.length > 4000 ||
        (reply != null && (reply is! String || !uuid.hasMatch(reply))) ||
        (preview != null && (preview is! String || preview.length > 4000))) {
      throw const FormatException('Invalid text draft');
    }
    return ChatTextDraft(
      text,
      id: id,
      replyTo: reply as String?,
      preview: preview as String?,
    );
  }
}

/// Account/conversation-scoped secure storage; serialization prevents late writes
/// from restoring a draft after its queued-message cleanup.
class ChatTextDraftStore {
  ChatTextDraftStore(
    this.account,
    this.target,
    this.checkSession, {
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();
  final String account, target;
  final Future<void> Function() checkSession;
  final FlutterSecureStorage _storage;
  static final _locks = <String, Future<void>>{};
  static final _redactedDrafts = <String, Set<String>>{};
  String get _key =>
      'kingclub.text-draft.${base64UrlEncode(utf8.encode(jsonEncode([account, target])))}';
  static Future<ChatTextDraftStore> open(String account, String target) async {
    final guard = await ChatFileDraftStore.open(account, target);
    return ChatTextDraftStore(account, target, guard.checkSession);
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final key = _key;
    final task = (_locks[key] ?? Future<void>.value()).then((_) async {
      await checkSession();
      return action();
    });
    final tail = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _locks[key] = tail;
    try {
      return await task;
    } finally {
      if (identical(_locks[key], tail)) _locks.remove(key);
    }
  }

  Future<ChatTextDraft?> read() => _exclusive(() async {
    final raw = await _storage.read(key: _key);
    await checkSession();
    return raw == null ? null : ChatTextDraft.parse(raw);
  });
  Future<void> write(ChatTextDraft? draft) => _exclusive(() async {
    var value = draft;
    if (value != null && (_redactedDrafts[_key]?.contains(value.id) ?? false)) {
      value = ChatTextDraft(value.text, id: value.id);
    }
    if (value == null || value.text.isEmpty && value.replyTo == null) {
      await _storage.delete(key: _key);
    } else {
      final raw = jsonEncode(value.toJson());
      ChatTextDraft.parse(raw);
      await _storage.write(key: _key, value: raw);
    }
  });

  /// Removes only the quote; pending user text is not part of history deletion.
  Future<void> redactReply(Set<String>? messageIds) => _exclusive(() async {
    final raw = await _storage.read(key: _key);
    await checkSession();
    if (raw == null) return;
    final draft = ChatTextDraft.parse(raw);
    if (draft.replyTo == null ||
        (messageIds != null && !messageIds.contains(draft.replyTo))) {
      return;
    }
    (_redactedDrafts[_key] ??= {}).add(draft.id);
    await _storage.write(
      key: _key,
      value: jsonEncode(ChatTextDraft(draft.text, id: draft.id).toJson()),
    );
  });
  Future<void> remove(String id) => _exclusive(() async {
    final raw = await _storage.read(key: _key);
    await checkSession();
    if (raw != null && ChatTextDraft.parse(raw).id == id) {
      await _storage.delete(key: _key);
    }
  });
}
