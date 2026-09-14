import '../../messaging/data/group_chat_repository.dart';
import '../../messaging/presentation/group_qr_preview_page.dart';
import '../../../core/session/secure_session_store.dart';

import 'package:uuid/uuid.dart';

import '../../messaging/data/messaging_repository.dart';
import '../../../core/design_system/king_notice.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../profile_settings/data/profile_repository.dart';

class MemberScannerPage extends StatefulWidget {
  const MemberScannerPage({super.key});
  @override
  State<MemberScannerPage> createState() => _MemberScannerPageState();
}

class _MemberScannerPageState extends State<MemberScannerPage>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _repo = ProfileRepository();
  bool _busy = false, _active = true;
  String? _error;
  int _generation = 0;
  bool _invalid = false;
  StreamSubscription<void>? _session;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _generation++;
      unawaited(_controller.stop());
      if (mounted) {
        setState(() => _error = '登录状态已变化，请重新进入');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _active = s == AppLifecycleState.resumed;
    if (!_active) {
      _generation++;
    }
    if (!_controller.value.hasCameraPermission) return;
    if (_active && !_busy && !_invalid) {
      unawaited(_controller.start());
    } else {
      unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    _generation++;
    _session?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _scan(BarcodeCapture capture) async {
    if (_busy || !_active || _invalid) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final generation = ++_generation;
    try {
      await _controller.stop();
      final messaging = await MessagingRepository.open();
      if (!mounted || !_active || _invalid || generation != _generation) return;
      if (code.startsWith('KC:G:')) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            allowSnapshotting: false,
            builder: (_) => GroupQrPreviewPage(
              code: code,
              repository: GroupChatRepository(messaging),
            ),
          ),
        );
      } else {
        final result = await _repo.call('K260912000507', {'code': code});
        if (!mounted || !_active || _invalid || generation != _generation) {
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            allowSnapshotting: false,
            builder: (_) => MemberCardPreview(
              profile: result,
              code: code,
              repository: messaging,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted && !_invalid && generation == _generation) {
        setState(() => _error = '无法识别或二维码已失效，请对方刷新二维码');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      if (mounted && _active && !_invalid && _error == null) {
        try {
          await _controller.start();
        } catch (_) {
          if (mounted && !_invalid) {
            setState(() => _error = '相机恢复失败，请重试');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('扫一扫')),
    body: Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _scan,
          errorBuilder: (context, error) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('无法打开相机，请允许相机权限后重试'),
                TextButton(
                  onPressed: () => _controller.start(),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.black87,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? (_busy ? '正在读取二维码…' : '请扫描 KINGCLUB 个人或群二维码')),
                  if (_error != null && !_invalid)
                    TextButton(
                      onPressed: () {
                        setState(() => _error = null);
                        _controller.start();
                      },
                      child: const Text('重新扫描'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class MemberCardPreview extends StatefulWidget {
  const MemberCardPreview({
    super.key,
    required this.profile,
    this.code,
    this.repository,
  });
  final String? code;
  final MessagingRepository? repository;
  final Map<String, dynamic> profile;
  @override
  State<MemberCardPreview> createState() => _MemberCardPreviewState();
}

class _MemberCardPreviewState extends State<MemberCardPreview> {
  final _note = TextEditingController();
  final _requestId = const Uuid().v4();
  String? _sentNote;
  String? _status;
  bool _sending = false;

  Future<void> _requestFriend() async {
    if (_sending ||
        _status != null ||
        widget.code == null ||
        widget.repository == null) {
      return;
    }
    setState(() => _sending = true);
    _sentNote ??= _note.text.trim();
    try {
      final result = await widget.repository!.requestFromQr(
        code: widget.code!,
        requestId: _requestId,
        note: _sentNote!,
      );
      if (!mounted) return;
      setState(
        () => _status = switch (result['status']) {
          'friends' => '你们已经互相关注',
          'incoming' => '对方已申请，请到新的朋友中处理',
          'accepted' => '申请已通过',
          'rejected' => '申请已被拒绝',
          'pending' => '申请已发送，等待对方确认',
          _ => throw const FormatException('申请状态无效'),
        },
      );
    } catch (e) {
      if (mounted) KingNotice.of(context).show(e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  late final Future<File?> _avatar = ProfileRepository().image(
    widget.profile['avatar'] as Map?,
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('会员资料')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<File?>(
              future: _avatar,
              builder: (context, s) => CircleAvatar(
                radius: 48,
                backgroundImage: s.data == null ? null : FileImage(s.data!),
                child: s.data == null ? const Icon(Icons.person_outline) : null,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.profile['nickname'] as String,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 14),
            Text(widget.profile['bio'] as String? ?? ''),
            if (widget.profile['isSelf'] != true &&
                widget.code != null &&
                widget.repository != null) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _note,
                maxLength: 120,
                enabled: !_sending && _sentNote == null && _status == null,
                decoration: const InputDecoration(hintText: '填写申请说明'),
              ),
              if (_status == null)
                FilledButton(
                  onPressed: _sending ? null : _requestFriend,
                  child: Text(
                    _sending
                        ? '正在提交'
                        : _sentNote == null
                        ? '申请好友'
                        : '重试申请',
                  ),
                )
              else
                Text(_status!, textAlign: TextAlign.center),
            ],
            if (widget.profile['isSelf'] == true)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text('这是你的个人二维码'),
              ),
          ],
        ),
      ),
    ),
  );
}
