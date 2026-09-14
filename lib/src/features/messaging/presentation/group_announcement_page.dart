import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/group_chat_repository.dart';
import '../../auth/domain/auth_repository.dart';
import 'legacy_messaging_components.dart';

class GroupAnnouncementPage extends StatefulWidget {
  const GroupAnnouncementPage({
    super.key,
    required this.groupId,
    required this.repository,
  });
  final String groupId;
  final GroupChatRepository repository;
  @override
  State<GroupAnnouncementPage> createState() => _GroupAnnouncementPageState();
}

class _GroupAnnouncementPageState extends State<GroupAnnouncementPage> {
  final _text = TextEditingController();
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  Map<String, dynamic>? _details;
  String? _error;
  bool _invalid = false, _saving = false, _editing = false;
  int _generation = 0, _version = 0, _membership = 0;
  void _discardDeniedDraft(Object error) {
    if (error is AuthFailure &&
        const {
          'CHAT_GROUP_ACCESS_DENIED',
          'CHAT_GROUP_MANAGE_DENIED',
          'CHAT_GROUP_MEMBERSHIP_CONFLICT',
          'AUTH_MEMBERSHIP_RESTRICTED',
          'MEMBERSHIP_REQUIRED',
          'SESSION_CHANGED',
          'SESSION_REVOKED',
        }.contains(error.code)) {
      _details = null;
      _editing = false;
      _text.clear();
    }
  }

  bool get _canEdit {
    final details = _details;
    if (_invalid || details == null) return false;
    return (details['members'] as List).cast<Map>().any(
      (member) =>
          member['account'] == widget.repository.account &&
          (member['role'] == 'admin' ||
              (member['role'] == 'owner' &&
                  details['ownerAccount'] == widget.repository.account)),
    );
  }

  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      if (!mounted) return;
      setState(() {
        _invalid = true;
        _generation++;
        _details = null;
        _editing = false;
        _text.clear();
        _error = '登录状态已变化';
      });
    });
    _events = KingclubRealtime.shared.events.listen((event) {
      if (!_invalid &&
          !_saving &&
          (event['eventType'] == 'chat.group.changed' ||
              event['eventType'] == 'connection.ready')) {
        unawaited(_load());
      }
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_invalid) return;
    final generation = ++_generation;
    try {
      final details = await widget.repository.details(widget.groupId);
      if (!mounted || _invalid || generation != _generation) return;
      if (details['announcementVersion'] is! num ||
          details['membershipVersion'] is! num) {
        throw const FormatException('群公告服务尚未更新');
      }
      setState(() {
        _details = details;
        _error = null;
        if (_editing &&
            (!_canEdit ||
                _membership != (details['membershipVersion'] as num).toInt())) {
          _editing = false;
          _text.clear();
          _error = '成员权限已变化，请重新查看公告';
        }
      });
    } catch (error) {
      if (mounted && !_invalid && generation == _generation) {
        setState(() {
          _details = null;
          _discardDeniedDraft(error);
          _error = error.toString();
        });
      }
    }
  }

  void _edit() {
    if (!_canEdit || _saving) return;
    setState(() {
      _text.text = _details!['announcementText'] as String? ?? '';
      _version = (_details!['announcementVersion'] as num).toInt();
      _membership = (_details!['membershipVersion'] as num).toInt();
      _editing = true;
    });
  }

  Future<void> _save() async {
    if (!_canEdit || !_editing || _saving) return;
    final text = _text.text.trim();
    if (text.length > 2000) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.repository.announcement(
        widget.groupId,
        text: text,
        expectedVersion: _version,
        membershipVersion: _membership,
      );
      if (!mounted || _invalid) return;
      if (result['groupId'] != widget.groupId ||
          result['text'] != text ||
          result['version'] is! num ||
          (result['version'] as num) < _version ||
          result['changed'] is! bool) {
        throw const FormatException('公告保存回执无效');
      }
      setState(() {
        _editing = false;
        _text.clear();
      });
      await _load();
    } catch (error) {
      if (mounted && !_invalid)
        setState(() {
          _discardDeniedDraft(error);
          _error = error.toString();
        });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _session?.cancel();
    _events?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(
        children: [
          LegacyMessagingHeader(
            title: '群公告',
            onBack: () => Navigator.maybePop(context),
            trailing: _canEdit
                ? TextButton(
                    onPressed: _saving ? null : (_editing ? _save : _edit),
                    child: Text(_editing ? '发布' : '编辑'),
                  )
                : null,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextButton(
                onPressed: _invalid || _saving ? null : _load,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _editing && !_invalid
                  ? Column(
                      children: [
                        TextField(
                          key: const ValueKey('group-announcement-input'),
                          controller: _text,
                          enabled: !_saving && _canEdit,
                          minLines: 8,
                          maxLines: null,
                          maxLength: 2000,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            hintText: '填写群公告，清空后发布可移除公告',
                          ),
                        ),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() {
                                  _editing = false;
                                  _text.clear();
                                }),
                          child: const Text('取消编辑'),
                        ),
                      ],
                    )
                  : SelectableText(
                      _details == null
                          ? ''
                          : ((_details!['announcementText'] as String?)
                                        ?.isNotEmpty ==
                                    true
                                ? _details!['announcementText'] as String
                                : '暂无群公告'),
                      style: const TextStyle(
                        color: Color(0xFFC9B69E),
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}
