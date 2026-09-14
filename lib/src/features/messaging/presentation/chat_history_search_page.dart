import 'dart:async';

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
  });
  final HistorySearch search;
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
  Timer? _debounce;
  int _generation = 0;
  int? _before;
  bool _busy = false, _invalid = false, _foreground = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _input.clear();
      _clear();
      if (mounted) setState(() => _error = '登录状态已变化');
    });
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      if (event['eventType'] == 'connection.ready' ||
          event['eventType'] == 'chat.relationship.changed' ||
          event['eventType'] == 'chat.read.changed' ||
          event['eventType'] == 'chat.settings.changed' ||
          event['eventType'] == 'chat.group.changed' ||
          event['eventType'] == 'chat.group.read') {
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
  }

  void _changed() {
    _clear();
    if (mounted) {
      setState(() {});
    }
    if (!_invalid && _foreground && _input.text.trim().isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 300), () => _load());
    }
  }

  Future<void> _load({bool more = false}) async {
    final query = _input.text.trim();
    if (_invalid ||
        !_foreground ||
        _busy ||
        query.isEmpty ||
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
      final result = await widget.search(query, before);
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
        previous = sequence;
      }
      if (result['hasMore'] == true && page.isEmpty) {
        throw const FormatException('Invalid search cursor');
      }
      setState(() {
        if (!more) {
          _items.clear();
        }
        _items.addAll(page.reversed);
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
              onChanged: (_) => _changed(),
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
                          : _input.text.trim().isEmpty
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
                      final date = DateTime.tryParse(
                        row['createdDate']?.toString() ?? '',
                      )?.toLocal();
                      return ListTile(
                        onTap: widget.onSelected == null
                            ? null
                            : () => widget.onSelected!(row),
                        title: Text(
                          row['text'] as String,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${row['sender']}${date == null ? '' : ' · ${date.toString().split('.').first}'}',
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
