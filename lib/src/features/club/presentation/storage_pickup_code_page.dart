import 'dart:async';

import 'package:flutter/material.dart';

enum StoragePickupScenario { ready, partial, collected, unavailable, offline }

class StoragePickupCodePage extends StatefulWidget {
  const StoragePickupCodePage({
    this.scenario = StoragePickupScenario.ready,
    super.key,
  });

  final StoragePickupScenario scenario;

  @override
  State<StoragePickupCodePage> createState() => _StoragePickupCodePageState();
}

class _StoragePickupCodePageState extends State<StoragePickupCodePage>
    with WidgetsBindingObserver {
  static const _gold = Color(0xFFC9B69E);
  static const _muted = Color(0xFF9E9589);

  Timer? _timer;
  int _seconds = 30;
  int _generation = 1;
  bool _privacyCovered = false;

  bool get _canShowCode =>
      !_privacyCovered &&
      widget.scenario != StoragePickupScenario.offline &&
      widget.scenario != StoragePickupScenario.unavailable &&
      widget.scenario != StoragePickupScenario.collected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_canShowCode) return;
      if (_seconds <= 1) {
        _issueNewCode();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _issueNewCode();
    } else if (mounted) {
      setState(() => _privacyCovered = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.52),
            radius: 0.9,
            colors: [Color(0xEF252018), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(30, 18, 30, 42),
                  children: [
                    const Text(
                      'ITEM PICKUP CODE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _gold,
                        fontSize: 14,
                        letterSpacing: 2.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _codeArea(),
                    const SizedBox(height: 14),
                    _statusText(),
                    const SizedBox(height: 28),
                    _details(),
                    const SizedBox(height: 30),
                    _instructions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('storage-pickup-back'),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: _gold, size: 21),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '取件凭证',
                style: TextStyle(
                  color: _gold,
                  fontSize: 19,
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

  Widget _codeArea() {
    final String coverText = switch (widget.scenario) {
      StoragePickupScenario.offline => '当前离线\n请联系工作人员安全核验',
      StoragePickupScenario.unavailable => '当前暂停取件',
      StoragePickupScenario.collected => '物品已取出',
      _ when _privacyCovered => '凭证已隐藏\n回到前台后重新签发',
      _ => '',
    };
    return Center(
      child: Container(
        key: ValueKey('storage-pickup-code-$_generation'),
        width: 252,
        height: 252,
        color: Colors.white,
        alignment: Alignment.center,
        child: _canShowCode
            ? Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.qr_code_2, size: 232, color: Colors.black),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF263EAC),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'K',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                color: const Color(0xFFF0F0F0),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Text(
                  coverText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, height: 1.6),
                ),
              ),
      ),
    );
  }

  Widget _statusText() {
    if (!_canShowCode) {
      return TextButton.icon(
        key: const ValueKey('storage-pickup-refresh'),
        onPressed: widget.scenario == StoragePickupScenario.ready
            ? _issueNewCode
            : null,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('重新签发凭证'),
      );
    }
    return Column(
      children: [
        Text(
          '$_seconds 秒后自动更新',
          style: const TextStyle(color: _gold, fontSize: 13),
        ),
        const SizedBox(height: 7),
        const Text(
          '仅向工作人员出示，请勿截图分享',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _details() {
    final remaining = widget.scenario == StoragePickupScenario.partial
        ? '35%（部分交付）'
        : '65%';
    return Column(
      children: [
        _detailRow('品名', '轩尼诗 VSOP'),
        _detailRow('英文名', 'Hennessy VSOP'),
        _detailRow('数量', '1 瓶'),
        _detailRow('剩余量', remaining),
        _detailRow('存入日期', '2026-08-20'),
        _detailRow('到期日期', '2026-09-19'),
        _detailRow('状态', _scenarioLabel()),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF271F15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: _gold, fontSize: 14)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructions() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STORAGE INSTRUCTIONS:',
          style: TextStyle(
            color: _gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '1、开瓶后的洋酒、红酒、清酒有效期为 30 天；\n'
          '2、未开瓶酒类有效期为 60 天；\n'
          '3、各类饮料、食品不提供存取；\n'
          '4、最终交付状态以工作人员核验结果为准。',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.7),
        ),
        SizedBox(height: 18),
        Center(
          child: Text(
            'UI Mock · 不含账号、URL 或永久储物编号',
            style: TextStyle(color: Color(0xFF554D44), fontSize: 11),
          ),
        ),
      ],
    );
  }

  String _scenarioLabel() => switch (widget.scenario) {
    StoragePickupScenario.ready => '可取',
    StoragePickupScenario.partial => '部分交付，剩余可取',
    StoragePickupScenario.collected => '已取出',
    StoragePickupScenario.unavailable => '暂停取件',
    StoragePickupScenario.offline => '离线，需人工核验',
  };

  void _issueNewCode() {
    if (!mounted) return;
    setState(() {
      _seconds = 30;
      _generation++;
      _privacyCovered = false;
    });
  }
}
