import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/profile_repository.dart';

class RealPersonalQrPage extends StatefulWidget {
  const RealPersonalQrPage({super.key, this.onBack, this.repository});
  final ProfileRepository? repository;
  final VoidCallback? onBack;
  @override
  State<RealPersonalQrPage> createState() => _RealPersonalQrPageState();
}

class _RealPersonalQrPageState extends State<RealPersonalQrPage>
    with WidgetsBindingObserver {
  late final _repo = widget.repository ?? ProfileRepository();
  Timer? _timer;
  Stopwatch? _validity;
  int _ttl = 0;
  int _generation = 0;
  String? _code, _error;
  Map<String, dynamic>? _profile;
  File? _avatar;
  bool _busy = false, _foreground = true;
  int get _remaining =>
      (_ttl - (_validity?.elapsed.inSeconds ?? 0)).clamp(0, 600);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _foreground) {
        setState(() {});
        if (_code != null && _remaining <= 60 && !_busy && _error == null) {
          _refresh();
        }
      }
    });
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _repo.load();
      if (!mounted) return;
      setState(() => _profile = p);
      final f = await _repo.image(p['avatar'] as Map?);
      if (mounted) setState(() => _avatar = f);
    } catch (_) {
      if (mounted) setState(() => _error = '资料加载失败，请刷新重试');
    }
  }

  Future<void> _refresh() async {
    if (_busy || !_foreground) return;
    final gen = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await _repo.call('K260912000506', {});
      if (!mounted || gen != _generation || !_foreground) return;
      setState(() {
        _code = r['code'] as String;
        _ttl = (r['ttlSeconds'] as num).toInt();
        _validity = Stopwatch()..start();
      });
    } catch (_) {
      if (mounted && gen == _generation) {
        setState(() => _error = '二维码获取失败，请检查网络后重试');
      }
    } finally {
      if (mounted && gen == _generation) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _foreground = s == AppLifecycleState.resumed;
    if (!_foreground) {
      _generation++;
      _code = null;
      _busy = false;
    } else {
      _refresh();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _foreground && _code != null && _remaining > 0;
    final r = MediaQuery.sizeOf(context).width.clamp(0, 600) / 750;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('我的二维码'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: bounds.maxHeight),
              child: Padding(
                padding: EdgeInsets.only(top: 30 * r, bottom: 100 * r),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 480 * r,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8 * r),
                              child: SizedBox.square(
                                dimension: 80 * r,
                                child: _avatar == null
                                    ? const ColoredBox(
                                        color: Color(0xFF29241D),
                                        child: Icon(
                                          Icons.person_outline,
                                          color: Color(0xFFC9B69E),
                                        ),
                                      )
                                    : Image.file(_avatar!, fit: BoxFit.cover),
                              ),
                            ),
                            SizedBox(width: 20 * r),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _profile?['nickname'] as String? ??
                                        '加载会员资料…',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 30 * r,
                                      color: const Color(0xFFBBBBBB),
                                    ),
                                  ),
                                  SizedBox(height: 5 * r),
                                  Text(
                                    _profile?['memberId'] as String? ?? '',
                                    style: TextStyle(
                                      fontSize: 22 * r,
                                      color: const Color(0xFF747474),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 40 * r),
                      GestureDetector(
                        onTap: _busy ? null : _refresh,
                        child: Container(
                          key: const ValueKey('real-member-qr-surface'),
                          width: 500 * r,
                          height: 500 * r,
                          padding: EdgeInsets.all(20 * r),
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: ready
                              ? QrImageView(
                                  data: _code!,
                                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.white,
                                  embeddedImage: const AssetImage(
                                    'assets/legacy/aa/kingLogo.png',
                                  ),
                                  embeddedImageStyle: QrEmbeddedImageStyle(
                                    size: Size(68 * r, 68 * r),
                                  ),
                                )
                              : (_busy
                                    ? const CircularProgressIndicator()
                                    : Text(
                                        _foreground ? '点击重新获取二维码' : '二维码已隐藏',
                                        style: TextStyle(
                                          fontSize: 24 * r,
                                          color: Colors.black54,
                                        ),
                                      )),
                        ),
                      ),
                      SizedBox(height: 30 * r),
                      Text(
                        '扫一扫上面的二维码图案，查看会员资料',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24 * r,
                          color: const Color(0xFF747474),
                        ),
                      ),
                      if (_error != null)
                        TextButton(
                          onPressed: () {
                            _refresh();
                            if (_profile == null) _loadProfile();
                          },
                          child: const Text(
                            '加载失败，点击重试',
                            style: TextStyle(
                              color: Color(0xFFE06B6B),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
