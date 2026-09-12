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
  Timer? _timer, _expiryTimer;
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
    _expiryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _epoch++;
    _timer?.cancel();
    _expiryTimer?.cancel();
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
      _error = null;
    });
    try {
      final detail = await widget.repository.detail(_item.ref);
      if (!mounted || epoch != _epoch) return;
      setState(() => _item = detail);
      if (!detail.canPickup) {
        _expiryTimer?.cancel();
        setState(() {
          _loading = false;
          _token = null;
        });
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
      _expiryTimer?.cancel();
      _expiryTimer = Timer(remaining, () {
        if (mounted) setState(() => _token = null);
      });
      // Refresh before expiry while the current code remains visible.
      // Never blend two QR patterns: replace the payload in a single frame.
      final refreshAfter = remaining > const Duration(seconds: 10)
          ? remaining - const Duration(seconds: 5)
          : remaining;
      _timer = Timer(refreshAfter, _renew);
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _expiryTimer?.cancel();
          _token = null;
          _loading = false;
          _error = '提取码暂不可用，请刷新后重试';
        });
      }
    }
  }

  Future<void> _delete() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.removeExpired(_item.ref);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: KingBackButton.leftOffset(context),
                      ),
                      child: IconButton(
                        key: ValueKey(
                          _item.status == 'expired'
                              ? 'storage-delete'
                              : 'storage-refresh',
                        ),
                        tooltip: _item.status == 'expired' ? '删除' : '刷新',
                        onPressed: _loading
                            ? null
                            : (_item.status == 'expired' ? _delete : _renew),
                        icon: Icon(
                          _item.status == 'expired'
                              ? Icons.delete_outline
                              : Icons.refresh,
                          size: 17,
                        ),
                        style: IconButton.styleFrom(
                          foregroundColor: const Color(0xFFC9B69E),
                          highlightColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
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
                  if (_item.status == 'expired')
                    Text(
                      _error ??
                          (_item.category == 'wine'
                              ? '存酒已过期，请联系工作人员核实'
                              : '物品已过期，请联系工作人员核实'),
                      key: const ValueKey('storage-expired-notice'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFC9B69E),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    )
                  else
                    Center(
                      child: SizedBox.square(
                        dimension: MediaQuery.sizeOf(context).width * .58,
                        child: ColoredBox(
                          key: const ValueKey('storage-code-background'),
                          color: _item.status == 'expired'
                              ? Colors.transparent
                              : Colors.white,
                          child: _token != null
                              ? QrImageView(
                                  key: const ValueKey('storage-real-code'),
                                  data: _token!,
                                  padding: const EdgeInsets.all(10),
                                  version: QrVersions.auto,
                                )
                              : _loading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    _error ??
                                        (_item.status == 'expired'
                                            ? (_item.category == 'wine'
                                                  ? '存酒已过期，请联系工作人员核实'
                                                  : '物品已过期，请联系工作人员核实')
                                            : _item.status == 'collected'
                                            ? '已取出'
                                            : '当前物品不可提取'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _item.status == 'expired'
                                          ? const Color(0xFFC9B69E)
                                          : const Color(0xFF695B48),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  if (_item.category == 'item') ...[
                    SizedBox(height: _item.status == 'expired' ? 20 : 46),
                    _detailRow('物品名', _item.name),
                    if (_item.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: ColoredBox(
                          color: const Color(0xFF2B2115),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 4,
                            ),
                            child: Text(
                              _item.description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFC9B69E),
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      ),
                    _detailRow('数量', '${_item.quantity}'),
                    _detailRow('获取日期', _date(_item.storedAt)),
                    _detailRow('过期日期', _date(_item.expiresAt)),
                    if (_item.maximumValue != null)
                      _detailRow(
                        '最大抵用金额',
                        '￥${_item.maximumValue!.toStringAsFixed(2)}',
                      ),
                  ] else ...[
                    if (_item.status != 'expired') ...[
                      const SizedBox(height: 12),
                      Text(
                        _token != null
                            ? '请向工作人员出示，提取码会自动更新'
                            : '当前展示物品详情，暂不生成提取码',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0x99C9B69E),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 30),
                    ] else
                      const SizedBox(height: 20),
                    for (final row in [
                      ('品名', _item.name),
                      ('英文名', _item.englishName),
                      ('数量', '${_item.quantity}'),
                      ('剩余量', '${_item.remainingPercent.toStringAsFixed(0)}%'),
                      ('储存日期', _date(_item.storedAt)),
                      ('有效期', _date(_item.expiresAt)),
                    ])
                      _detailRow(row.$1, row.$2),
                  ],
                  if (_item.category == 'wine') ...[
                    const SizedBox(height: 18),
                    const Text(
                      'STORAGE INSTRUCTIONS:\n\n1、开瓶后的洋酒、红酒、清酒有效期为30天；\n2、未开瓶的酒类有效期60天；\n3、各类饮料、食品恕不提供存取。',
                      style: TextStyle(
                        color: Color(0xFF8B8174),
                        fontSize: 12,
                        height: 1.8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Row(
      children: [
        Text(
          '$label：',
          style: const TextStyle(color: Color(0xFF9E9589), fontSize: 15),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2B2115),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Color(0xFFC9B69E), fontSize: 15),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  String _date(String value) => value.isEmpty
      ? '—'
      : (DateTime.tryParse(value)?.toLocal().toString().split('.').first ??
            value);
}
