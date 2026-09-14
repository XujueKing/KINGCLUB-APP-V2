import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/group_chat_repository.dart';
import 'direct_chat_page.dart';
import 'legacy_messaging_components.dart';

class GroupQrPreviewPage extends StatefulWidget {
  const GroupQrPreviewPage({
    super.key,
    required this.code,
    required this.repository,
    this.events,
  });
  final String code;
  final GroupChatRepository repository;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<GroupQrPreviewPage> createState() => _GroupQrPreviewPageState();
}

class _GroupQrPreviewPageState extends State<GroupQrPreviewPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _preview;
  String? _error;
  bool _invalid = false, _foreground = true, _busy = false;
  int _generation = 0;
  Timer? _expiry;
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;

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
      if (event['eventType'] == 'chat.group.changed' ||
          event['eventType'] == 'connection.ready') {
        _clear();
        if (mounted) {
          setState(() {});
          unawaited(_load());
        }
      }
    });
    unawaited(_load());
  }

  void _clear() {
    _generation++;
    _preview = null;
    _busy = false;
    _expiry?.cancel();
  }

  Future<void> _load() async {
    if (_invalid || !_foreground || _busy) {
      return;
    }
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _preview = null;
      _error = null;
    });
    try {
      if (!RegExp(r'^KC:G:[0-9A-F]{32}$').hasMatch(widget.code)) {
        throw const FormatException('Invalid group code');
      }
      final result = await widget.repository.previewQr(widget.code);
      if (!mounted || generation != _generation) {
        return;
      }
      final id = result['groupId'],
          name = result['groupName'],
          count = result['memberCount'];
      final expires = DateTime.tryParse(result['expiresAt']?.toString() ?? '');
      if (id is! String ||
          !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
              .hasMatch(id) ||
          name is! String ||
          name.isEmpty ||
          count is! int ||
          count < 1 ||
          result['alreadyMember'] is! bool ||
          expires == null ||
          !expires.isAfter(DateTime.now())) {
        throw const FormatException('Invalid group preview');
      }
      final remaining = expires.difference(DateTime.now());
      _expiry?.cancel();
      _expiry = Timer(
        remaining > const Duration(minutes: 10)
            ? const Duration(minutes: 10)
            : remaining,
        () {
          if (mounted && generation == _generation) {
            setState(() {
              _preview = null;
              _error = '二维码已过期，请重新扫描';
            });
          }
        },
      );
      setState(() => _preview = result);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = '二维码已失效或无法读取，请重新扫描');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
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
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_preview != null) ...[
                      Text(
                        _preview!['groupName'] as String,
                        style: const TextStyle(
                          color: Color(0xFFC9B69E),
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${_preview!['memberCount']}位群成员',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      if (_preview!['alreadyMember'] == true)
                        TextButton(
                          onPressed: () {
                            final preview = _preview;
                            if (_invalid || preview == null) {
                              return;
                            }
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => DirectChatPage(
                                  groupId: preview['groupId'] as String,
                                  peerName: preview['groupName'] as String,
                                  repository: widget.repository.messaging,
                                ),
                              ),
                            );
                          },
                          child: const Text('进入群聊'),
                        )
                      else
                        const Text(
                          '你尚未加入此群，可联系群成员邀请加入',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                    ],
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.grey)),
                    if (_error != null && !_invalid)
                      TextButton(
                        onPressed: _busy ? null : _load,
                        child: const Text('重试'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
