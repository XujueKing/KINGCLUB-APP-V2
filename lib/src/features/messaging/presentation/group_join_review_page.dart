import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/group_chat_repository.dart';
import '../../contacts/presentation/public_member_page.dart';
import 'chat_member_avatar.dart';
import 'legacy_messaging_components.dart';

class GroupJoinReviewPage extends StatefulWidget {
  const GroupJoinReviewPage({
    super.key,
    required this.groupId,
    required this.repository,
    this.events,
  });
  final String groupId;
  final GroupChatRepository repository;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<GroupJoinReviewPage> createState() => _GroupJoinReviewPageState();
}

class _GroupJoinReviewPageState extends State<GroupJoinReviewPage>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _items = [];
  int? _version;
  int _generation = 0;
  String? _next, _error;
  bool _busy = false, _saving = false, _invalid = false, _foreground = true;
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  final _profiles = <String, Future<Map<String, dynamic>>>{};
  Future<void>? _loading;
  bool _reloadAgain = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _clear();
      if (mounted) {
        setState(() => _error = '登录状态已变化');
      }
    });
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      final data = event['data'];
      if (event['eventType'] == 'chat.group.changed' &&
          data is Map &&
          data['groupId'] is String &&
          data['groupId'] != widget.groupId) {
        return;
      }
      if (event['eventType'] == 'chat.group.changed' ||
          event['eventType'] == 'connection.ready') {
        unawaited(_load());
      }
    });
    unawaited(_load());
  }

  void _clear() {
    _generation++;
    _items = [];
    _profiles.clear();
    _next = null;
    _version = null;
    _busy = false;
  }

  Future<void> _load({bool more = false}) {
    if (!mounted ||
        _invalid ||
        !_foreground ||
        (more && (_busy || _next == null))) {
      return Future<void>.value();
    }
    final active = _loading;
    if (active != null) {
      if (!more) {
        _reloadAgain = true;
        setState(() {
          _clear();
          _busy = true;
        });
      }
      return active;
    }
    return _loading = _drainLoads(more).whenComplete(() => _loading = null);
  }

  Future<void> _drainLoads(bool more) async {
    do {
      _reloadAgain = false;
      await _readPage(more: more);
      more = false;
    } while (_reloadAgain && mounted && !_invalid && _foreground);
  }

  Future<void> _readPage({required bool more}) async {
    final before = more ? _next : null;
    if (!more) {
      _clear();
    }
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.joinApplications(
        widget.groupId,
        before: before,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      final version = result['membershipVersion'];
      final raw = result['items'];
      final next = result['nextCursor'];
      if (result['groupId'] != widget.groupId ||
          version is! int ||
          version < 0 ||
          version > 4294967295 ||
          raw is! List ||
          (next != null &&
              (next is! String ||
                  !RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(next) ||
                  (before != null &&
                      BigInt.parse(next) >= BigInt.parse(before)) ||
                  raw.isEmpty))) {
        throw const FormatException('审核列表无效');
      }
      final items = raw
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      for (final item in items) {
        if (item['applicationId'] is! String ||
            item['applicant'] is! String ||
            item['note'] is! String ||
            !const [
              'pending',
              'accepted',
              'rejected',
              'expired',
              'canceled',
            ].contains(item['status'])) {
          throw const FormatException('审核条目无效');
        }
      }
      if (more && _version != version) {
        _reloadAgain = true;
        return;
      }
      setState(() {
        final merged = {
          for (final item in [..._items, ...items]) item['applicationId']: item,
        };
        _items = merged.values.toList();
        _version = version;
        _next = next as String?;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _clear();
          _error = '无法读取入群申请，请确认管理权限后重试';
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _review(Map<String, dynamic> item, bool accept) async {
    if (_invalid || _saving || _busy || _version == null || !_foreground) {
      return;
    }
    final version = _version!, generation = _generation;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: Text(
          accept ? '同意此人加入群聊？' : '拒绝此入群申请？',
          style: const TextStyle(color: Color(0xFFC9B69E), fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
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
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.reviewApplication(
        groupId: widget.groupId,
        applicationId: item['applicationId'] as String,
        accept: accept,
        membershipVersion: version,
      );
      if (mounted && !_invalid) {
        await _load();
      }
    } catch (_) {
      if (mounted && !_invalid) {
        // Re-read authority before making any retry actionable.
        await _load();
        if (mounted && !_invalid) {
          setState(() => _error = '审核结果未确认，请刷新后重试');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _clear();
    if (mounted) {
      setState(() {});
    }
    if (_foreground) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _clear();
    _session?.cancel();
    _events?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _label(String status) => switch (status) {
    'accepted' => '已同意',
    'rejected' => '已拒绝',
    'expired' => '已过期',
    'canceled' => '已取消',
    _ => '待审核',
  };

  Widget _applicant(Map<String, dynamic> item) {
    final account = item['applicant'] as String;
    final profile = cachedChatAvatarProfile(
      _profiles,
      account,
      () =>
          widget.repository.messaging.call('K260913000612', {'peer': account}),
    );
    return ListTile(
      key: ValueKey('group-applicant-${item['applicationId']}-$_generation'),
      leading: ChatMemberAvatar(account: account, profile: profile),
      title: FutureBuilder<Map<String, dynamic>>(
        future: profile,
        builder: (_, snapshot) {
          final nickname = snapshot.connectionState == ConnectionState.done
              ? (snapshot.data?['nickname'])
              : null;
          return Text(
            nickname is String && nickname.trim().isNotEmpty ? nickname : '申请人',
            style: const TextStyle(color: Color(0xFFC9B69E), fontSize: 16),
          );
        },
      ),
      subtitle: Text(
        item['note'] as String,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
      onTap: _busy || _saving || _invalid || !_foreground
          ? null
          : () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PublicMemberPage(
                    account: account,
                    repository: widget.repository.messaging,
                  ),
                ),
              );
              if (mounted && !_invalid) await _load();
            },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(
        children: [
          LegacyMessagingHeader(
            title: '入群申请',
            onBack: () => Navigator.maybePop(context),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.grey)),
          if (!_invalid && _foreground)
            TextButton(
              onPressed: _busy || _saving ? null : _load,
              child: const Text('刷新'),
            ),
          Expanded(
            child: ListView(
              children: [
                if (_items.isEmpty &&
                    !_busy &&
                    !_invalid &&
                    _foreground &&
                    _error == null)
                  const Center(
                    child: Text('暂无入群申请', style: TextStyle(color: Colors.grey)),
                  ),
                for (final item in _items) ...[
                  _applicant(item),
                  if (item['status'] == 'pending')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _saving || _busy
                              ? null
                              : () => _review(item, false),
                          child: const Text('拒绝'),
                        ),
                        TextButton(
                          onPressed: _saving || _busy
                              ? null
                              : () => _review(item, true),
                          child: const Text('同意'),
                        ),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _label(item['status'] as String),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  const Divider(
                    indent: 24,
                    endIndent: 24,
                    color: Color(0xFF1A1611),
                    height: 1,
                  ),
                ],
                if (_next != null)
                  TextButton(
                    onPressed: _busy || _saving
                        ? null
                        : () => _load(more: true),
                    child: const Text('加载更多'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
