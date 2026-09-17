import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/secure_session_store.dart';
import '../data/chat_text_draft_store.dart';

class ConversationDraftPreview extends StatefulWidget {
  const ConversationDraftPreview({
    super.key,
    required this.account,
    required this.target,
    required this.preview,
    required this.style,
    this.openStore = ChatTextDraftStore.open,
  });
  final String account, target, preview;
  final TextStyle style;
  final Future<ChatTextDraftStore> Function(String, String) openStore;
  @override
  State<ConversationDraftPreview> createState() =>
      _ConversationDraftPreviewState();
}

class _ConversationDraftPreviewState extends State<ConversationDraftPreview> {
  StreamSubscription<void>? _drafts, _sessions;
  ChatTextDraftStore? _store;
  ChatTextDraft? _draft;
  int _epoch = 0;
  bool _reading = false, _again = false, _invalid = false;

  @override
  void initState() {
    super.initState();
    _sessions = SecureSessionStore.changes.stream.listen((_) {
      _epoch++;
      _invalid = true;
      _store = null;
      if (mounted) setState(() => _draft = null);
    });
    _bind();
  }

  void _bind() {
    _epoch++;
    _invalid = false;
    _store = null;
    _draft = null;
    _drafts?.cancel();
    _drafts = ChatTextDraftStore.changes(
      widget.account,
      widget.target,
    ).listen((_) => _load());
    _load();
  }

  Future<void> _load() async {
    if (_invalid) return;
    if (_reading) {
      _again = true;
      return;
    }
    _reading = true;
    try {
      do {
        _again = false;
        final epoch = _epoch;
        try {
          final store =
              _store ?? await widget.openStore(widget.account, widget.target);
          if (!mounted || _invalid || epoch != _epoch) continue;
          _store = store;
          final draft = await store.read();
          if (!mounted || _invalid || epoch != _epoch) continue;
          setState(() => _draft = draft);
        } catch (_) {
          // A draft read must not replace the conversation list with an error.
        }
      } while (mounted && !_invalid && _again);
    } finally {
      _reading = false;
    }
  }

  @override
  void didUpdateWidget(covariant ConversationDraftPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account ||
        oldWidget.target != widget.target ||
        oldWidget.openStore != widget.openStore) {
      _bind();
    }
  }

  @override
  void dispose() {
    _epoch++;
    _drafts?.cancel();
    _sessions?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final content = draft == null
        ? null
        : draft.text.isNotEmpty
        ? draft.text
        : draft.replyTo != null
        ? '引用消息'
        : null;
    return Text(
      content == null ? widget.preview : '[草稿] $content',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}
