import 'dart:async';

import 'chat_timestamp.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/chat_history_store.dart';
import '../data/chat_media_event_scope.dart';
import '../data/chat_media_deletion.dart';

import 'package:flutter/material.dart';

import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import 'legacy_messaging_components.dart';

typedef HistorySearch = Future<Map<String, dynamic>> Function(
  String query,
  int? before,
);

class ChatHistorySearchPage extends StatefulWidget {
  const ChatHistorySearchPage({
    super.key,
    required this.search,
    this.events,
    this.onSelected,
    this.senderLabel,
    this.groupId,
    this.mediaSearch,
    this.account,
    this.localConversation,
  });
  final HistorySearch search;
  final HistorySearch? mediaSearch;
  final String? groupId;
  final String? account;
  final String? localConversation;
  final String Function(String account)? senderLabel;
  final ValueChanged<Map<String, dynamic>>? onSelected;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<ChatHistorySearchPage> createState() => _ChatHistorySearchPageState();
}

class _ChatHistorySearchPageState extends State<ChatHistorySearchPage>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _items = <Map<String, dynamic>>[];
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  void Function()? _stopDeletion;
  final _removedIds = <String>{};
  Timer? _debounce;
  int _generation = 0;
  int? _before;
  bool _busy = false, _invalid = false, _foreground = true;
  String? _error;
  String? _messageType;
  bool _localOnly = false;
  bool get _hasCriteria =>
      _messageType != null || _input.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stopDeletion = ChatMediaDeletion.listen((event) {
      if (_invalid ||
          event.account != widget.account ||
          event.group != (widget.groupId != null)) {
        return;
      }
      _removedIds.add(event.messageId);
      if (_busy || _items.any((row) => row['messageId'] == event.messageId)) {
        _changed();
      }
    });
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _input.clear();
      _clear();
      if (mounted) setState(() => _error = '登录状态已变化');
    });
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      if (affectsChatMedia(
            event,
            group: widget.groupId != null,
            scopeId: widget.groupId,
          ) ||
          (widget.groupId == null &&
              event['eventType'] == 'chat.read.changed')) {
        _changed();
      }
    });
  }

  void _clear() {
    _debounce?.cancel();
    _generation++;
    _items.clear();
    _before = null;
    _busy = false;
    _error = null;
    _localOnly = false;
  }

  void _changed() {
    _clear();
    if (mounted) {
      setState(() {});
    }
    if (!_invalid && _foreground && _hasCriteria) {
      _debounce = Timer(const Duration(milliseconds: 300), () => _load());
    }
  }

  Future<void> _load({bool more = false}) async {
    final query = _input.text.trim();
    final messageType = _messageType;
    if (_invalid ||
        !_foreground ||
        _busy ||
        !_hasCriteria ||
        (more && _before == null)) {
      return;
    }
    final generation = ++_generation;
    final before = more ? _before : null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Future<Map<String, dynamic>> localSearch() async {
        final store = await ChatHistoryStore.open(widget.account!);
        return store.search(
          widget.localConversation!,
          query: query,
          messageType: messageType,
          before: before,
          isActive: () =>
              mounted && !_invalid && _foreground && generation == _generation,
        );
      }

      Map<String, dynamic> result;
      if (more && _localOnly) {
        result = await localSearch();
      } else {
        try {
          result = messageType == null
              ? await widget.search(query, before)
              : await widget.mediaSearch!(messageType, before);
        } on AuthFailure catch (error) {
          if (error.code != 'NETWORK_ERROR' ||
              widget.account == null ||
              widget.localConversation == null) {
            rethrow;
          }
          result = await localSearch();
        }
      }
      if (!mounted || generation != _generation) {
        return;
      }
      final raw = result['messages'];
      if (raw is! List || result['hasMore'] is! bool) {
        throw const FormatException('Invalid search result');
      }
      final page = raw
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      var previous = 0;
      for (final row in page) {
        final sequence = row['sequence'];
        if (sequence is! int ||
            sequence <= previous ||
            (before != null && sequence >= before) ||
            row['messageId'] is! String ||
            row['text'] is! String ||
            row['sender'] is! String) {
          throw const FormatException('Invalid search message');
        }
        if (messageType != null && row['messageType'] != messageType) {
          throw const FormatException('Unexpected media search result');
        }
        previous = sequence;
      }
      if (result['hasMore'] == true && page.isEmpty) {
        throw const FormatException('Invalid search cursor');
      }
      setState(() {
        _localOnly = result['localOnly'] == true;
        if (!more) {
          _items.clear();
        }
        _items.addAll(
          page.reversed.where(
            (row) =>
                !_removedIds.contains(row['messageId']) &&
                !const {'hidden', 'recalled'}.contains(row['messageType']),
          ),
        );
        _before = result['hasMore'] == true
            ? page.first['sequence'] as int
            : null;
        _busy = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _items.clear();
        _before = null;
        _busy = false;
        _error = '搜索未完成，请重试';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _changed();
  }

  @override
  void dispose() {
    _clear();
    _session?.cancel();
    _events?.cancel();
    _stopDeletion?.call();
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(
        children: [
          LegacyMessagingHeader(
            title: '查找聊天内容',
            onBack: () => Navigator.pop(context),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const ValueKey('chat-history-search-input'),
              controller: _input,
              enabled: !_invalid,
              autofocus: true,
              maxLength: 100,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) {
                _messageType = null;
                _changed();
              },
              onSubmitted: (_) {
                _debounce?.cancel();
                _load();
              },
              decoration: const InputDecoration(
                hintText: '搜索聊天内容',
                counterText: '',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (widget.mediaSearch != null)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final entry in const {
                    'image': '图片',
                    'voice': '语音',
                    'video': '视频',
                    'file': '文件',
                    'location': '位置',
                  }.entries)
                    TextButton(
                      key: ValueKey('history-type-${entry.key}'),
                      onPressed: _invalid
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              _input.clear();
                              _messageType = entry.key;
                              _changed();
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: _messageType == entry.key
                            ? legacyMessageGold
                            : const Color(0x88FFFFFF),
                      ),
                      child: Text(entry.value),
                    ),
                ],
              ),
            ),
          if (_localOnly)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '当前仅搜索本机已保存的记录',
                style: TextStyle(color: Color(0x88FFFFFF), fontSize: 12),
              ),
            ),
          Expanded(
            child: !_foreground
                ? const SizedBox.shrink()
                : _error != null
                ? Center(
                    child: TextButton(
                      onPressed: _invalid ? null : () => _load(),
                      child: Text(_error!),
                    ),
                  )
                : _items.isEmpty
                ? Center(
                    child: Text(
                      _busy
                          ? '正在搜索…'
                          : !_hasCriteria
                          ? '输入关键词查找聊天记录'
                          : '未找到相关聊天内容',
                      style: const TextStyle(color: Color(0x88FFFFFF)),
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length + (_before != null ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: Color(0x14FFFFFF),
                    ),
                    itemBuilder: (_, index) {
                      if (index == _items.length) {
                        return TextButton(
                          onPressed: _busy ? null : () => _load(more: true),
                          child: Text(_busy ? '正在搜索…' : '加载更早结果'),
                        );
                      }
                      final row = _items[index];
                      final date = chatTimestampLabel(
                        row['createdDate']?.toString(),
                        null,
                      );
                      return ListTile(
                        onTap: widget.onSelected == null
                            ? null
                            : () => widget.onSelected!(row),
                        title: Text(
                          row['messageType'] == 'file'
                              ? (row['fileName'] as String? ??
                                    row['text'] as String)
                              : row['text'] as String,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          [
                            widget.senderLabel?.call(row['sender'] as String) ??
                                row['sender'] as String,
                            ?date,
                          ].where((part) => part.isNotEmpty).join(' · '),
                          style: const TextStyle(
                            color: Color(0x88FFFFFF),
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
