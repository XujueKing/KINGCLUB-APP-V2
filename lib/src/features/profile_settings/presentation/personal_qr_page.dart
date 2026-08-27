import 'dart:async';

import 'package:flutter/material.dart';

class PersonalQrPage extends StatefulWidget {
  const PersonalQrPage({super.key});

  @override
  State<PersonalQrPage> createState() => _PersonalQrPageState();
}

class _PersonalQrPageState extends State<PersonalQrPage>
    with WidgetsBindingObserver {
  static const _gold = Color(0xFFC9B69E);
  static const _muted = Color(0xFF747474);
  Timer? _timer;
  int _remainingSeconds = 600;
  int _visualSeed = 0;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_hidden && _remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    if (mounted) setState(() => _hidden = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remainingSeconds == 0;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _QrHeader(onBack: () => Navigator.pop(context)),
            const Spacer(flex: 2),
            const SizedBox(
              width: 272,
              child: Row(
                children: [
                  CircleAvatar(radius: 28, backgroundColor: Color(0xFFF0ECE5)),
                  SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '杨嘉琪',
                        style: TextStyle(
                          color: Color(0xFFBBBBBB),
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'K45600000199',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              key: ValueKey('personal-qr-code-$_visualSeed'),
              onTap: (_hidden || expired) ? _refresh : null,
              child: Container(
                width: 276,
                height: 276,
                color: Colors.white,
                alignment: Alignment.center,
                child: _hidden
                    ? _QrCover(label: '二维码已隐藏\n点击刷新')
                    : expired
                    ? _QrCover(label: '二维码已过期\n点击刷新')
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.qr_code_2, size: 254, color: Colors.black),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: Color(0xFF263EAC),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'K',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '扫一扫上面的二维码图案，加我成为朋友',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 9),
            Text(
              expired ? '已过期' : '有效期 ${_formatTime(_remainingSeconds)}',
              style: TextStyle(
                color: expired ? const Color(0xFFE06B6B) : _gold,
                fontSize: 12,
              ),
            ),
            TextButton.icon(
              key: const ValueKey('personal-qr-refresh'),
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新二维码'),
            ),
            const Spacer(flex: 3),
            const Padding(
              padding: EdgeInsets.only(bottom: 30),
              child: Text(
                '仅供离线 UI 演示，不含真实身份凭证',
                style: TextStyle(color: Color(0xFF494949), fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _refresh() => setState(() {
    _remainingSeconds = 600;
    _hidden = false;
    _visualSeed++;
  });

  static String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }
}

class _QrCover extends StatelessWidget {
  const _QrCover({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F2F2),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, height: 1.5),
        ),
      ),
    );
  }
}

class _QrHeader extends StatelessWidget {
  const _QrHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('personal-qr-back'),
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFFC9B69E),
              size: 21,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '我的二维码',
                style: TextStyle(
                  color: Color(0xFFC9B69E),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
