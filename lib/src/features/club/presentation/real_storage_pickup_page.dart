import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/design_system/king_theme.dart';
import '../../../core/design_system/king_components.dart';
import '../data/storage_repository.dart';

class RealStoragePickupPage extends StatefulWidget {
  const RealStoragePickupPage({
    super.key,
    required this.item,
    required this.repository,
  });
  final StorageItem item;
  final StorageRepository repository;
  @override
  State<RealStoragePickupPage> createState() => _RealStoragePickupPageState();
}

class _RealStoragePickupPageState extends State<RealStoragePickupPage>
    with WidgetsBindingObserver {
  late StorageItem _item = widget.item;
  String? _token, _error;
  bool _loading = false, _foreground = true;
  int _epoch = 0;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _renew();
  }

  @override
  void dispose() {
    _epoch++;
    _token = null;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _epoch++;
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _token = null;
        _loading = false;
      });
    }
    if (_foreground) _renew();
  }

  Future<void> _renew() async {
    if (_loading || !_foreground) return;
    _timer?.cancel();
    final epoch = ++_epoch;
    final elapsed = Stopwatch()..start();
    setState(() {
      _loading = true;
      _token = null;
      _error = null;
    });
    try {
      final detail = await widget.repository.detail(_item.ref);
      if (!mounted || epoch != _epoch) return;
      setState(() => _item = detail);
      if (!detail.canPickup) {
        setState(() => _loading = false);
        return;
      }
      final result = await widget.repository.issue(_item.ref);
      if (!mounted || epoch != _epoch || !_foreground) return;
      final remaining =
          Duration(seconds: (result['expiresInSeconds'] as num).toInt()) -
          elapsed.elapsed;
      if (remaining <= Duration.zero) throw StateError('请求耗时过长');
      setState(() {
        _token = result['token'] as String;
        _loading = false;
      });
      _timer = Timer(remaining, () {
        if (mounted) {
          setState(() => _token = null);
          _renew();
        }
      });
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _token = null;
          _loading = false;
          _error = '提取码暂不可用，请刷新后重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.55),
          radius: .95,
          colors: [Color(0xFF2A261E), Colors.black],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'ITEM PICKUP CODE',
                    style: KingTheme.headerTitleStyle,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: KingBackButton.leftOffset(context),
                      ),
                      child: KingBackButton(
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width * .13,
                  vertical: 20,
                ),
                children: [
                  Center(
                    child: SizedBox.square(
                      dimension: MediaQuery.sizeOf(context).width * .58,
                      child: _loading
                          ? const Center(
                              child: CircularProgressIndicator(strokeWidth: 1),
                            )
                          : _token != null
                          ? ColoredBox(
                              color: Colors.white,
                              child: QrImageView(
                                key: const ValueKey('storage-real-code'),
                                data: _token!,
                                padding: const EdgeInsets.all(10),
                                version: QrVersions.auto,
                              ),
                            )
                          : Center(
                              child: Text(
                                _error ??
                                    (_item.status == 'expired'
                                        ? '存酒已过期，请联系工作人员核实'
                                        : _item.status == 'collected'
                                        ? '已取出'
                                        : '当前物品不可提取'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFC9B69E),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _token != null ? '请向工作人员出示，提取码会自动更新' : '当前展示物品详情，暂不生成提取码',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0x99C9B69E),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 30),
                  for (final row in [
                    ('品名', _item.name),
                    ('英文名', _item.englishName),
                    ('数量', '${_item.quantity}'),
                    ('剩余量', '${_item.remainingPercent.toStringAsFixed(0)}%'),
                    ('储存日期', _date(_item.storedAt)),
                    ('有效期', _date(_item.expiresAt)),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${row.$1}：',
                            style: const TextStyle(
                              color: Color(0xFF9E9589),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2B2115),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  row.$2,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: Color(0xFFC9B69E),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextButton(
                    onPressed: _loading ? null : _renew,
                    child: const Text('刷新状态'),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _item.category == 'item' ? _item.description : 'STORAGE INSTRUCTIONS:\n\n1、开瓶后的洋酒、红酒、清酒有效期为30天；\n2、未开瓶的酒类有效期60天；\n3、各类饮料、食品恕不提供存取。',
                    style: const TextStyle(
                      color: Color(0xFF8B8174),
                      fontSize: 12,
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  String _date(String value) => value.isEmpty
      ? '—'
      : (DateTime.tryParse(value)?.toLocal().toString().split('.').first ??
            value);
}
