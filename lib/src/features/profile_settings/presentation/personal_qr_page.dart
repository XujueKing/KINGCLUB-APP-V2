import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/design_system/king_components.dart';
import '../data/profile_avatar_store.dart';

enum PersonalQrScenario {
  ready,
  nearlyExpired,
  expired,
  offline,
  issueError,
  refreshError,
  delayedIssue,
  sessionInvalid,
}

class PersonalQrPage extends StatefulWidget {
  const PersonalQrPage({
    super.key,
    this.initialScenario = PersonalQrScenario.ready,
    this.onBack,
    this.onSessionResetRequested,
    this.avatarStore,
    this.tickInterval = const Duration(seconds: 1),
  });

  final PersonalQrScenario initialScenario;
  final VoidCallback? onBack;
  final VoidCallback? onSessionResetRequested;
  final ProfileAvatarStore? avatarStore;

  // Kept for source compatibility with the previous short-code UI tests. The
  // permanent mini-program QR no longer starts a timer.
  final Duration tickInterval;

  @override
  State<PersonalQrPage> createState() => _PersonalQrPageState();
}

class _PersonalQrPageState extends State<PersonalQrPage> {
  static const _muted = Color(0xFF747474);
  static const _stableQrData =
      'https://www.wuyexin.cn/view/static/kingclubaddfriend/?type=0&qrCode=K45600000799';
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    if (widget.initialScenario == PersonalQrScenario.sessionInvalid) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSessionInvalid(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _QrHeader(onBack: _finishBack),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewportWidth = math.min(
                    constraints.maxWidth,
                    MediaQuery.sizeOf(context).width,
                  );
                  final scale = viewportWidth / 750;

                  return SingleChildScrollView(
                    key: const ValueKey('personal-qr-scroll'),
                    padding: EdgeInsets.only(
                      top: 215 * scale,
                      bottom: 100 * scale,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 480 * scale,
                            child: Row(
                              children: [
                                ClipRRect(
                                  key: const ValueKey('personal-qr-avatar'),
                                  borderRadius: BorderRadius.circular(
                                    8 * scale,
                                  ),
                                  child: SizedBox.square(
                                    dimension: 80 * scale,
                                    child: _avatarPath == null
                                        ? Image.asset(
                                            'assets/legacy/profile/touxiang.png',
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.high,
                                          )
                                        : Image.file(
                                            File(_avatarPath!),
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.high,
                                            errorBuilder: (_, _, _) =>
                                                Image.asset(
                                                  'assets/legacy/profile/touxiang.png',
                                                  fit: BoxFit.cover,
                                                ),
                                          ),
                                  ),
                                ),
                                SizedBox(width: 20 * scale),
                                Expanded(
                                  child: Text(
                                    'K45600000799',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 22 * scale,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 40 * scale),
                          Semantics(
                            label: '长期个人好友二维码',
                            image: true,
                            child: Container(
                              key: const ValueKey('personal-qr-code'),
                              width: 500 * scale,
                              height: 500 * scale,
                              padding: EdgeInsets.all(44 * scale),
                              color: Colors.white,
                              child: ExcludeSemantics(
                                child: QrImageView(
                                  key: const ValueKey('personal-qr-image'),
                                  data: _stableQrData,
                                  version: QrVersions.auto,
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Colors.black,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Colors.black,
                                  ),
                                  embeddedImage: const AssetImage(
                                    'assets/legacy/profile/kingLogo.png',
                                  ),
                                  embeddedImageStyle: QrEmbeddedImageStyle(
                                    size: Size.square(96 * scale),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 30 * scale),
                          Text(
                            '扫一扫上面的二维码图案，加我成为朋友',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 24 * scale,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSessionInvalid() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('personal-qr-session-dialog'),
        title: const Text('登录状态已失效'),
        content: const Text('个人二维码已隐藏，请重新登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('personal-qr-session-confirm'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (widget.onSessionResetRequested != null) {
      widget.onSessionResetRequested!();
    } else {
      _finishBack();
    }
  }

  Future<void> _loadAvatar() async {
    try {
      final saved =
          await (widget.avatarStore ?? LocalProfileAvatarStore.instance).load();
      if (saved != null && mounted) setState(() => _avatarPath = saved);
    } catch (_) {
      // The packaged legacy avatar remains the safe fallback.
    }
  }

  void _finishBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.maybePop(context);
    }
  }
}

class _QrHeader extends StatelessWidget {
  const _QrHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: KingBackButton.leftOffset(context),
            top: KingBackButton.safeAreaOffset.dy,
            child: KingBackButton(
              key: const ValueKey('personal-qr-back'),
              onPressed: onBack,
            ),
          ),
          const Text(
            '我的二维码',
            key: ValueKey('personal-qr-title'),
            style: TextStyle(
              color: Color(0xFFC9B69E),
              fontSize: 19,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
