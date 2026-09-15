import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/secure_session_store.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../data/group_chat_repository.dart';
import 'direct_chat_page.dart';
import 'legacy_messaging_components.dart';

class GroupJoinRequestPage extends StatefulWidget {
  const GroupJoinRequestPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.code,
    required this.repository,
    this.events,
  });
  final String groupId, groupName, code;
  final GroupChatRepository repository;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<GroupJoinRequestPage> createState() => _GroupJoinRequestPageState();
}

class _GroupJoinRequestPageState extends State<GroupJoinRequestPage>
    with WidgetsBindingObserver {
  final _note = TextEditingController();
  String? _submittedNote, _status, _error;
  bool _busy = false, _invalid = false, _foreground = true;
  int _generation = 0;
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  bool _checking = false, _checkAgain = false, _canEnter = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _generation++;
      _invalid = true;
      _note.clear();
      _submittedNote = null;
      _status = null;
      _canEnter = false;
      if (mounted) {
        setState(() => _error = '登录状态已变化');
      }
    });
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      if (event['eventType'] == 'chat.group.changed' ||
          event['eventType'] == 'connection.ready') {
        if (_busy && _status == null) {
          _checkAgain = true;
          return;
        }
        unawaited(_checkMembership());
      }
    });
  }

  Future<void> _checkMembership() async {
    if (!mounted || _invalid || !_foreground || _status == null) return;
    if (_checking) {
      _checkAgain = true;
      return;
    }
    final generation = _generation;
    setState(() {
      _checking = true;
      _canEnter = false;
    });
    try {
      final details = await widget.repository.details(widget.groupId);
      if (!mounted || _invalid || generation != _generation) return;
      final members = details['members'];
      if (details['groupId'] != widget.groupId ||
          members is! List ||
          !members.whereType<Map>().any(
            (member) =>
                member['account'] == widget.repository.messaging.account,
          )) {
        throw const FormatException('群成员信息无效');
      }
      setState(() {
        _status = 'accepted';
        _canEnter = true;
        _error = null;
      });
    } catch (_) {
      if (mounted && !_invalid && generation == _generation) {
        setState(() => _error = '暂未确认入群，请稍后刷新');
      }
    } finally {
      _checking = false;
      if (mounted) setState(() {});
      if (_checkAgain) {
        _checkAgain = false;
        unawaited(_checkMembership());
      }
    }
  }

  Future<void> _submit() async {
    if (_busy || _invalid || !_foreground || _status != null) {
      return;
    }
    final generation = ++_generation;
    _submittedNote ??= _note.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.applyToGroup(
        groupId: widget.groupId,
        code: widget.code,
        note: _submittedNote!,
      );
      if (!mounted || generation != _generation || _invalid) {
        return;
      }
      setState(() => _status = result['status'] as String);
      if (_status == 'accepted' || _status == 'already_member' || _checkAgain) {
        _checkAgain = false;
        unawaited(_checkMembership());
      }
    } catch (_) {
      if (mounted && generation == _generation && !_invalid) {
        setState(() => _error = '申请未确认，请重试；若二维码已失效，请重新扫描');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _generation++;
    _canEnter = false;
    if (mounted) {
      setState(() {});
    }
    if (_foreground) unawaited(_checkMembership());
  }

  @override
  void dispose() {
    _generation++;
    _session?.cancel();
    _events?.cancel();
    _note.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String get _resultText => switch (_status) {
    'pending' => '申请已提交，等待群主或管理员审核',
    'accepted' => '申请已通过',
    'already_member' => '你已在群聊中',
    'rejected' => '申请未通过',
    'canceled' => '申请已取消',
    _ => '申请已过期，请重新扫描',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(
        children: [
          LegacyMessagingHeader(
            title: '申请入群',
            onBack: () => Navigator.maybePop(context),
          ),
          if (_invalid)
            const Text('登录状态已变化', style: TextStyle(color: Colors.grey)),
          if (!_invalid && _foreground)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        color: Color(0xFFC9B69E),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_status == null) ...[
                      TextField(
                        key: const ValueKey('group-join-note'),
                        controller: _note,
                        enabled: _submittedNote == null && !_busy,
                        maxLength: 200,
                        minLines: 2,
                        maxLines: 5,
                        style: const TextStyle(color: Color(0xFFC9B69E)),
                        decoration: const InputDecoration(
                          hintText: '填写申请备注（选填）',
                        ),
                      ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      TextButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_submittedNote == null ? '提交申请' : '重试申请'),
                      ),
                    ] else ...[
                      Text(
                        _resultText,
                        style: const TextStyle(color: Color(0xFFC9B69E)),
                      ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      if (_canEnter)
                        TextButton(
                          onPressed: () {
                            if (_invalid || !_foreground || !_canEnter) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => DirectChatPage(
                                  groupId: widget.groupId,
                                  peerName: widget.groupName,
                                  repository: widget.repository.messaging,
                                ),
                              ),
                            );
                          },
                          child: const Text('进入群聊'),
                        )
                      else
                        TextButton(
                          onPressed: _checking ? null : _checkMembership,
                          child: const Text('刷新入群状态'),
                        ),
                      TextButton(
                        onPressed: () => Navigator.maybePop(context),
                        child: const Text('返回群资料'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
