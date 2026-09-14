import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/group_chat_repository.dart';
import 'legacy_messaging_components.dart';

class GroupQrPage extends StatefulWidget {
  const GroupQrPage({
    super.key,
    required this.groupId,
    required this.repository,
  });
  final String groupId;
  final GroupChatRepository repository;

  @override
  State<GroupQrPage> createState() => _GroupQrPageState();
}

class _GroupQrPageState extends State<GroupQrPage> with WidgetsBindingObserver {
  String? _code, _name, _error;
  Stopwatch? _validity;
  int _ttl = 0;
  bool _foreground = true, _invalid = false, _busy = false;
  int _generation = 0;
  Timer? _timer;
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;

  bool get _ready =>
      _foreground &&
      !_invalid &&
      _code != null &&
      _validity != null &&
      _validity!.elapsed.inSeconds < _ttl;

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
    _events = KingclubRealtime.shared.events.listen((event) {
      if (event['eventType'] == 'chat.group.changed' ||
          event['eventType'] == 'connection.ready') {
        _clear();
        if (mounted) {
          setState(() {});
          unawaited(_load());
        }
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_foreground || _invalid) {
        return;
      }
      if (!_ready && _code != null) {
        setState(() => _code = null);
      }
      if (!_busy &&
          _error == null &&
          (_validity == null || _ttl - _validity!.elapsed.inSeconds <= 60)) {
        unawaited(_load());
      }
    });
    unawaited(_load());
  }

  void _clear() {
    _generation++;
    _code = null;
    _name = null;
    _validity = null;
    _ttl = 0;
    _busy = false;
  }

  Future<void> _load() async {
    if (_invalid || !_foreground || _busy) {
      return;
    }
    final generation = ++_generation;
    final started = Stopwatch()..start();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final details = await widget.repository.details(widget.groupId);
      if (!mounted || generation != _generation || _invalid || !_foreground) {
        return;
      }
      final result = await widget.repository.issueQr(widget.groupId);
      if (!mounted || generation != _generation || _invalid || !_foreground) {
        return;
      }
      final code = result['code'];
      final ttl = result['ttlSeconds'];
      final name = details['groupName'];
      if (result['groupId'] != widget.groupId ||
          code is! String ||
          !RegExp(r'^KC:G:[0-9A-F]{32}$').hasMatch(code) ||
          ttl is! int ||
          ttl <= 0 ||
          ttl > 600 ||
          name is! String ||
          name.isEmpty) {
        throw const FormatException('群二维码响应无效');
      }
      // Start at request time so network latency cannot extend validity.
      if (started.elapsed.inSeconds >= ttl) {
        throw const FormatException('群二维码已过期');
      }
      setState(() {
        _code = code;
        _name = name;
        _validity = started;
        _ttl = ttl;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          if (error is AuthFailure || error is FormatException) {
            _code = null;
            _name = null;
          }
          _error = '群二维码获取失败，请重试';
        });
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
    _timer?.cancel();
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
            title: '群二维码',
            onBack: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    children: [
                      if (_name != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            _name!,
                            style: const TextStyle(
                              color: Color(0xFFC9B69E),
                              fontSize: 18,
                            ),
                          ),
                        ),
                      if (_ready)
                        QrImageView(
                          data: _code!,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.all(20),
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                        ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      if (!_invalid)
                        TextButton(
                          onPressed: _busy ? null : _load,
                          child: const Text('刷新二维码'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
