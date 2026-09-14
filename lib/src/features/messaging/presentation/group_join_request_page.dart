import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/secure_session_store.dart';
import '../data/group_chat_repository.dart';
import 'legacy_messaging_components.dart';

class GroupJoinRequestPage extends StatefulWidget {
  const GroupJoinRequestPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.code,
    required this.repository,
  });
  final String groupId, groupName, code;
  final GroupChatRepository repository;
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
      if (mounted) {
        setState(() => _error = '登录状态已变化');
      }
    });
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
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _generation++;
    _session?.cancel();
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
