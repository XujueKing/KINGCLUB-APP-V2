import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/secure_session_store.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../auth/domain/auth_repository.dart';
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
  String? _applicationId;
  bool _busy = false, _invalid = false, _foreground = true, _restoring = true;
  bool _restoreFailed = false;
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
      _applicationId = null;
      _canEnter = false;
      if (mounted) {
        setState(() => _error = '登录状态已变化');
      }
    });
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      if (event['eventType'] == 'chat.group.changed' ||
          event['eventType'] == 'connection.ready') {
        if (_busy) {
          _checkAgain = true;
          return;
        }
        unawaited(_checkMembership());
      }
    });
    unawaited(_restoreApplication());
  }

  Future<void> _restoreApplication() async {
    if (!mounted || _invalid || !_foreground) return;
    final generation = _generation;
    setState(() {
      _restoring = true;
      _restoreFailed = false;
      _error = null;
    });
    try {
      final id = await widget.repository.savedJoinApplication(widget.groupId);
      if (!mounted || _invalid || generation != _generation) return;
      if (id != null) {
        setState(() {
          _applicationId = id;
          _status = 'unconfirmed';
        });
        await _checkMembership();
      }
    } catch (_) {
      // A local storage failure cannot imply approval or rejection.
      if (mounted && !_invalid && generation == _generation) {
        setState(() {
          _restoreFailed = true;
          _error = '无法读取上次入群申请，请重试';
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _restoring = false);
      }
    }
  }

  Future<void> _newApplication() async {
    if (_invalid || !_foreground || _busy || _checking) return;
    final id = _applicationId;
    if (id == null || !['rejected', 'canceled', 'expired'].contains(_status)) {
      return;
    }
    final generation = _generation;
    setState(() => _busy = true);
    try {
      await widget.repository.forgetJoinApplication(widget.groupId, id);
      if (!mounted || _invalid || generation != _generation) return;
      setState(() {
        _applicationId = null;
        _status = null;
        _submittedNote = null;
        _note.clear();
        _error = null;
      });
    } catch (_) {
      if (mounted && !_invalid && generation == _generation) {
        setState(() => _error = '暂时无法重新申请，请重试');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _flushStatusCheck();
    }
  }

  Future<void> _cancelApplication() async {
    if (_invalid ||
        !_foreground ||
        _busy ||
        _checking ||
        _status != 'pending') {
      return;
    }
    final id = _applicationId;
    if (id == null) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('撤回入群申请？'),
          content: const Text('撤回后，群主和管理员将无法再通过这次申请。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('保留申请'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认撤回'),
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
      final status = await widget.repository.cancelApplication(
        groupId: widget.groupId,
        applicationId: id,
      );
      if (!mounted || _invalid || !_foreground || generation != _generation) {
        return;
      }
      setState(() {
        _status = status;
        _canEnter = false;
        _error = null;
      });
    } catch (error) {
      if (mounted && !_invalid && generation == _generation) {
        setState(() => _error = '撤回结果未确认，请刷新后重试');
        if (error is AuthFailure && error.code == 'CHAT_GROUP_JOIN_RESOLVED') {
          _checkAgain = true;
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _flushStatusCheck();
    }
  }

  void _flushStatusCheck() {
    if (!_checkAgain || !mounted || _invalid || !_foreground || _busy) return;
    _checkAgain = false;
    if (_status == null) {
      unawaited(_restoreApplication());
    } else {
      unawaited(_checkMembership());
    }
  }

  Future<void> _checkMembership() async {
    if (!mounted || _invalid || !_foreground || _status == null) return;
    if (_checking || _busy) {
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
      if (!mounted || _invalid || generation != _generation) return;
      String? status;
      final applicationId = _applicationId;
      if (applicationId != null) {
        try {
          status = await widget.repository.ownApplicationStatus(
            groupId: widget.groupId,
            applicationId: applicationId,
          );
        } catch (_) {
          // An older deployment or failed status read cannot grant entry
          // or be interpreted as an application rejection.
        }
      }
      if (mounted && !_invalid && generation == _generation) {
        setState(() {
          if (status != null) _status = status;
          _error = status == null || status == 'accepted'
              ? '暂未确认入群，请稍后刷新'
              : null;
        });
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
    if (_busy ||
        _restoring ||
        _restoreFailed ||
        _invalid ||
        !_foreground ||
        _status != null) {
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
      setState(() {
        _status = result['status'] as String;
        _applicationId = result['applicationId'] as String?;
      });
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
      _flushStatusCheck();
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
    if (_foreground) {
      if (_busy) {
        _checkAgain = true;
        return;
      }
      if (_status == null) {
        unawaited(_restoreApplication());
      } else {
        unawaited(_checkMembership());
      }
    }
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
    'unconfirmed' => '已提交过入群申请，请刷新查看当前状态',
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
                        onPressed: _busy || _restoring || _restoreFailed
                            ? null
                            : _submit,
                        child: Text(_submittedNote == null ? '提交申请' : '重试申请'),
                      ),
                      if (_restoreFailed)
                        TextButton(
                          onPressed: _restoring || _busy
                              ? null
                              : _restoreApplication,
                          child: const Text('重试读取申请'),
                        ),
                    ] else ...[
                      Text(
                        _resultText,
                        style: const TextStyle(color: Color(0xFFC9B69E)),
                      ),
                      if (_status == 'pending' && _applicationId != null)
                        TextButton(
                          onPressed: _busy || _checking
                              ? null
                              : _cancelApplication,
                          child: const Text('撤回申请'),
                        ),
                      if (['rejected', 'canceled', 'expired'].contains(_status))
                        TextButton(
                          onPressed: _busy || _checking
                              ? null
                              : _newApplication,
                          child: const Text('重新申请'),
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
                          onPressed: _checking || _busy
                              ? null
                              : _checkMembership,
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
