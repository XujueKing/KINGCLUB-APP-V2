import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/group_chat_repository.dart';
import '../data/group_directory_store.dart';
import '../data/messaging_repository.dart';
import 'direct_chat_page.dart';
import 'legacy_messaging_components.dart';

class JoinedGroupsPage extends StatefulWidget {
  const JoinedGroupsPage({super.key, this.repository, this.store, this.events});
  final GroupChatRepository? repository;
  final GroupDirectoryStore? store;
  final Stream<Map<String, dynamic>>? events;

  @override
  State<JoinedGroupsPage> createState() => _JoinedGroupsPageState();
}

class _JoinedGroupsPageState extends State<JoinedGroupsPage>
    with WidgetsBindingObserver {
  GroupChatRepository? _repository;
  GroupDirectoryStore? _store;
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  List<Map<String, dynamic>> _items = [];
  String? _next, _error;
  bool _invalid = false, _foreground = true, _ready = false;
  bool _loading = false, _refreshPending = false;
  int _generation = 0;
  Future<void>? _active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _generation++;
      _invalid = true;
      if (mounted) {
        setState(() {
          _items = [];
          _next = null;
          _error = '登录状态已变化，请重新进入';
        });
      }
    });
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      if (event['eventType'] == 'chat.group.changed' ||
          event['eventType'] == 'connection.ready') {
        unawaited(_load(reset: true));
      }
    });
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final repository =
          widget.repository ??
          GroupChatRepository(await MessagingRepository.open());
      if (!mounted || _invalid) return;
      _repository = repository;
      _store = widget.store ?? GroupDirectoryStore(repository.account);
      try {
        final cached = await _store!.read();
        if (!mounted || _invalid) return;
        setState(() => _items = cached);
      } catch (_) {
        // A damaged or unavailable cache must not block the authoritative list.
      }
      if (!mounted || _invalid) return;
      _ready = true;
      await _load(reset: true);
    } catch (_) {
      if (mounted && !_invalid) {
        setState(() => _error = '群聊暂不可用，点击重试');
      }
    }
  }

  Future<void> _load({bool reset = false}) {
    if (!_ready || !mounted || _invalid || !_foreground) {
      return Future<void>.value();
    }
    if (_active != null) {
      if (reset) {
        _refreshPending = true;
        _generation++;
      }
      return _active!;
    }
    return _active = _drain(reset).whenComplete(() => _active = null);
  }

  Future<void> _drain(bool reset) async {
    do {
      _refreshPending = false;
      await _readPage(reset);
      reset = true;
    } while (_refreshPending && mounted && !_invalid && _foreground);
  }

  Future<void> _readPage(bool reset) async {
    if (!reset && _next == null) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _repository!.list(before: reset ? null : _next);
      if (!mounted || _invalid || generation != _generation) return;
      final rows = GroupDirectoryStore.parse(response['items']);
      final next = response['nextCursor'];
      if (next != null &&
          (next is! String || next.isEmpty || next == _next && !reset)) {
        throw const FormatException('群列表分页无效');
      }
      final merged = <String, Map<String, dynamic>>{
        if (!reset)
          for (final row in _items) row['groupId'] as String: row,
        for (final row in rows) row['groupId'] as String: row,
      };
      setState(() {
        _items = merged.values.toList();
        _next = next as String?;
      });
      try {
        await _store!.save(_items);
      } catch (_) {
        // Storage failure does not discard a successfully fetched page.
      }
    } catch (_) {
      if (mounted && !_invalid && generation == _generation) {
        setState(() => _error = '暂时无法更新群聊，点击重试');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    if (_invalid || !_foreground || _repository == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DirectChatPage(
          groupId: row['groupId'] as String,
          peerName: row['groupName'] as String,
          repository: _repository!.messaging,
        ),
      ),
    );
    if (mounted) await _load(reset: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _generation++;
    if (_foreground) unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _session?.cancel();
    _events?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(
        children: [
          LegacyMessagingHeader(
            title: '群聊',
            onBack: () => Navigator.maybePop(context),
          ),
          if (_error != null)
            TextButton(
              onPressed: _invalid
                  ? null
                  : () => _ready ? _load(reset: true) : _initialize(),
              child: Text(_error!, style: const TextStyle(color: Colors.grey)),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _items.length + 1,
                itemBuilder: (context, index) {
                  if (index == _items.length) {
                    if (_next != null) {
                      return TextButton(
                        onPressed: _loading ? null : () => _load(),
                        child: const Text('查看更多'),
                      );
                    }
                    if (_items.isEmpty &&
                        _ready &&
                        !_loading &&
                        _error == null) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            '暂无加入的群聊',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    return const SizedBox(height: 24);
                  }
                  final row = _items[index];
                  return ListTile(
                    key: ValueKey(row['groupId']),
                    leading: const Icon(
                      Icons.groups_outlined,
                      color: Color(0xFFC9B69E),
                    ),
                    title: Text(
                      row['groupName'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    subtitle: Text(
                      '${row['memberCount']}人',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    onTap: _invalid ? null : () => _open(row),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
