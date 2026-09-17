import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/secure_session_store.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../data/group_chat_repository.dart';
import '../data/messaging_repository.dart';
import 'legacy_messaging_components.dart';
import 'direct_chat_page.dart';

class GroupInvitationsPage extends StatefulWidget {
  const GroupInvitationsPage({super.key, this.repository, this.events});
  final GroupChatRepository? repository;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<GroupInvitationsPage> createState() => _GroupInvitationsPageState();
}

class _GroupInvitationsPageState extends State<GroupInvitationsPage>
    with WidgetsBindingObserver {
  GroupChatRepository? _repository;
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  List<Map<String, dynamic>> _items = [];
  String? _next, _error, _saving;
  bool _invalid = false, _loading = false;
  bool _foreground = true;
  int _generation = 0;
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
          _repository = null;
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
    unawaited(_load(reset: true));
  }

  Future<void> _load({bool reset = false}) async {
    if (_invalid || !_foreground || (!reset && (_loading || _next == null))) {
      return;
    }
    final generation = ++_generation;
    final before = reset ? null : _next;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository =
          _repository ??
          widget.repository ??
          GroupChatRepository(await MessagingRepository.open());
      if (!mounted || generation != _generation) return;
      _repository = repository;
      final response = await repository.invitations(before: before);
      if (!mounted || generation != _generation) return;
      final items = (response['items'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      final next = response['nextCursor'] as String?;
      if (next != null &&
          (items.isEmpty ||
              (before != null && BigInt.parse(next) >= BigInt.parse(before)))) {
        throw const FormatException('邀请分页无效');
      }
      setState(() {
        final all = {
          if (!reset)
            for (final item in _items) item['invitationId']: item,
        };
        for (final item in items) {
          all[item['invitationId']] = item;
        }
        _items = all.values.toList();
        _next = next;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _respond(Map<String, dynamic> item, bool accept) async {
    if (_invalid ||
        !_foreground ||
        _loading ||
        _saving != null ||
        _repository == null) {
      return;
    }
    final generation = _generation;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: Text(accept ? '加入群聊' : '拒绝邀请'),
        content: Text(item['groupName'] as String),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accept ? '加入' : '拒绝'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        _invalid ||
        !_foreground ||
        generation != _generation) {
      return;
    }
    setState(() {
      _saving = item['invitationId'] as String;
      _error = null;
    });
    try {
      final result = await _repository!.respondInvitation(
        item['groupId'] as String,
        item['invitationId'] as String,
        accept: accept,
      );
      if (!mounted || _invalid || !_foreground || generation != _generation) {
        return;
      }
      setState(() => item['status'] = result['status']);
      await _load(reset: true);
    } catch (e) {
      if (mounted && !_invalid && _foreground && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    if (_repository == null ||
        _invalid ||
        !_foreground ||
        _loading ||
        _saving != null) {
      return;
    }
    final generation = _generation;
    try {
      // A replayed acceptance is a receipt, not proof of current membership.
      final details = await _repository!.details(item['groupId'] as String);
      if (!mounted || _invalid || !_foreground || generation != _generation) {
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => DirectChatPage(
            groupId: item['groupId'] as String,
            peerName: details['groupName'] as String,
            repository: _repository!.messaging,
          ),
        ),
      );
    } catch (e) {
      if (mounted && !_invalid && _foreground && generation == _generation) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _generation++;
    if (!_foreground) {
      setState(() {
        _items = [];
        _next = null;
        _loading = false;
        _error = null;
      });
    } else {
      unawaited(_load(reset: true));
    }
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
            title: '群邀请',
            onBack: () => Navigator.maybePop(context),
          ),
          if (_error != null)
            TextButton(
              onPressed: _invalid ? null : () => _load(reset: true),
              child: Text(_error!, style: const TextStyle(color: Colors.grey)),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  for (final item in _items) ...[
                    ListTile(
                      leading: const Icon(
                        Icons.group_outlined,
                        color: Color(0xFFC9B69E),
                      ),
                      title: Text(
                        item['groupName'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        '邀请人：${item['inviter']}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      trailing: item['status'] == 'pending'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: _saving != null
                                      ? null
                                      : () => _respond(item, false),
                                  child: const Text('拒绝'),
                                ),
                                TextButton(
                                  onPressed: _saving != null
                                      ? null
                                      : () => _respond(item, true),
                                  child: const Text('加入'),
                                ),
                              ],
                            )
                          : item['status'] == 'accepted'
                          ? TextButton(
                              onPressed: _saving != null
                                  ? null
                                  : () => _open(item),
                              child: const Text('查看群聊'),
                            )
                          : Text(
                              {
                                    'rejected': '已拒绝',
                                    'expired': '已过期',
                                    'canceled': '已取消',
                                  }[item['status']] ??
                                  '',
                              style: const TextStyle(color: Colors.grey),
                            ),
                    ),
                    const Divider(
                      indent: 72,
                      endIndent: 24,
                      height: 1,
                      color: Color(0xFF1A1611),
                    ),
                  ],
                  if (_items.isEmpty && !_loading && _error == null)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          '暂无群邀请',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  if (_next != null)
                    TextButton(
                      onPressed: _loading ? null : () => _load(),
                      child: const Text('加载更多'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
