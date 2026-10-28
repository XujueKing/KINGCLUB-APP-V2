import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/media/cached_media_image.dart';
import '../../club/presentation/reservation_components.dart';
import '../../club/presentation/reservation_discovery_page.dart';
import '../../club/presentation/together_activity_page.dart';
import '../../club/presentation/together_activity_action.dart';
import '../../club/presentation/together_artwork_contrast.dart';
import '../../club/data/together_read_history.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/store_home_repository.dart';

typedef StoreActivityOpen = Future<void> Function(
  BuildContext context,
  String ref, {
  required bool join,
  required VoidCallback onViewed,
});
List<Map<String, dynamic>> _rows(Object? value) => (value as List? ?? [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();
bool _flag(Object? v) => v == true || v == 1;
String _text(Object? v) => v is String ? v : '';

class StoreHomePage extends StatefulWidget {
  const StoreHomePage({
    super.key,
    required this.storeRef,
    this.repository,
    this.onActivity,
    this.initialBrandName,
    this.initialBranchName,
  });
  final String storeRef;
  final String? initialBrandName, initialBranchName;
  final StoreHomeRepository? repository;
  final StoreActivityOpen? onActivity;
  @override
  State<StoreHomePage> createState() => _StoreHomeState();
}

class _StoreHomeState extends State<StoreHomePage> {
  late final _repository = widget.repository ?? StoreHomeRepository();
  final _scroll = ScrollController();
  Map<String, dynamic>? _data;
  final _cache = <String, Map<String, dynamic>>{};
  String _section = 'featured';
  int _page = 0, _epoch = 0;
  bool _loading = true, _saving = false;
  String? _error;
  String? _opening;
  TogetherReadHistory? _readHistory;
  final _seen = <String>{};
  final _tabs = const ['featured', 'activities', 'booking', 'about'];
  String t(String value) => reservationText(context, value);
  Map get _store => _data?['store'] as Map? ?? {};
  bool get _hasActivities =>
      _rows(_cache['featured:0']?['activities'] ?? _data?['activities'])
          .isNotEmpty;
  @override
  void initState() {
    super.initState();
    _load();
    _loadReadHistory();
  }

  Future<void> _loadReadHistory() async {
    final session = await SecureSessionStore().readSession();
    final account = (session?['account'] as Map?)?['userAccount'] as String?;
    if (account == null) return;
    final history = TogetherReadHistory(account);
    final seen = await history.load();
    if (mounted) {
      setState(() {
        _readHistory = history;
        _seen.addAll(seen);
      });
    }
  }

  @override
  void dispose() {
    _epoch++;
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    final section = _section, page = _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repository.home(
        widget.storeRef,
        section: section,
        page: page,
      );
      if (mounted && epoch == _epoch) {
        _cache['$section:$page'] = data;
        if (_cache.length > 8) {
          _cache.remove(_cache.keys.firstWhere((k) => k != 'featured:0'));
        }
        setState(() => _data = data);
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(
          () => _error = t(
            '店铺暂时无法加载，请重试|Store unavailable. Retry|店鋪暫時無法載入，請重試|โหลดร้านไม่สำเร็จ ลองอีกครั้ง',
          ),
        );
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  void _tab(String section, {int page = 0}) {
    if (_section == section && _page == page) return;
    _epoch++;
    final cached = _cache[section == 'about' ? 'featured:0' : '$section:$page'];
    setState(() {
      _section = section;
      _page = page;
      _data =
          cached ??
          {
            ...?_data,
            'activities': [],
            'vouchers': [],
            'products': [],
            'more': {},
          };
      _loading = cached == null;
      _error = null;
    });
    if (cached == null) _load();
  }

  Future<void> _refresh() async {
    _cache.clear();
    await _load();
  }

  Future<void> _openActivity(String ref, {bool join = false}) async {
    if (_opening != null || widget.onActivity == null) return;
    setState(() => _opening = ref);
    try {
      await widget.onActivity!(
        context,
        ref,
        join: join,
        onViewed: () {
          if (!mounted) return;
          setState(() => _seen.add(ref));
          unawaited(_readHistory?.mark(ref));
        },
      );
    } catch (_) {
      if (mounted) {
        _message(
          t(
            '活动暂不可用，请重试|Activity unavailable. Retry|活動暫不可用，請重試|กิจกรรมไม่พร้อม ลองอีกครั้ง',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _favourite() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await _repository.favourite(
        widget.storeRef,
        !_flag(_data?['favourite']),
      );
      if (mounted) {
        _cache.updateAll((_, v) => {...v, 'favourite': saved});
        setState(() => _data = {...?_data, 'favourite': saved});
      }
    } catch (_) {
      if (mounted) {
        _message(t('操作未完成，请重试|Please retry|操作未完成，請重試|โปรดลองอีกครั้ง'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _contact() async {
    final phone = _text(_store['phone']);
    if (phone.isEmpty) {
      _message(
        t(
          '商家暂未公开联系电话|No public phone yet|商家暫未公開聯絡電話|ร้านยังไม่เผยแพร่เบอร์โทร',
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: phone));
    if (mounted) {
      _message(t('联系电话已复制|Phone number copied|聯絡電話已複製|คัดลอกเบอร์โทรแล้ว'));
    }
  }

  Future<void> _address() async {
    final address = _text(_store['address']);
    if (address.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: address));
    if (mounted) {
      _message(
        t(
          '地址已复制，可粘贴到地图导航|Address copied for maps|地址已複製，可貼到地圖導航|คัดลอกที่อยู่แล้ว',
        ),
      );
    }
  }

  void _book() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReservationDiscoveryPage(
        storeRef: widget.storeRef,
        cityCode: _text(_store['cityCode']),
      ),
    ),
  );
  Widget _image(
    Object? source, {
    double? height,
    double? width,
    BoxFit fit = BoxFit.cover,
  }) {
    final url = _text(source);
    final fallback = ColoredBox(
      color: const Color(0xff26231f),
      child: Center(
        heightFactor: 1,
        child: Icon(
          Icons.storefront_outlined,
          size: height == 64 ? 28 : 64,
          color: reservationGold,
        ),
      ),
    );
    return SizedBox(
      height: height,
      width: width,
      child: url.isEmpty
          ? fallback
          : CachedMediaImage(
              url,
              fit: fit,
              private: false,
              cacheWidth: height == 64 ? 160 : 960,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }

  static const _bg = Color(0xff080808), _muted = Color(0xff9e9a96);
  TextStyle _type(
    double size, {
    Color color = const Color(0xfff7f6f4),
    FontWeight weight = FontWeight.w400,
    double height = 1.4,
  }) => TextStyle(
    inherit: false,
    fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: 0,
    color: color,
    textBaseline: TextBaseline.alphabetic,
  );
  String get _brand => _text(_store['brandName']).isNotEmpty
      ? _text(_store['brandName'])
      : widget.initialBrandName?.trim().isNotEmpty == true
      ? widget.initialBrandName!
      : _text(_store['name']);
  String get _branch => _text(_store['branchName']).isNotEmpty
      ? _text(_store['branchName'])
      : widget.initialBranchName ?? '';
  Widget _brandLabel() => LayoutBuilder(
    builder: (context, constraints) {
      final style = _type(24, weight: FontWeight.w700, height: 1.2);
      final measure = TextPainter(
        text: TextSpan(text: _brand, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final size = _branch.isEmpty && measure.width > constraints.maxWidth
          ? (24 * constraints.maxWidth / measure.width).clamp(18.0, 24.0)
          : 24.0;
      measure.dispose();
      return Text(
        _brand,
        key: const ValueKey('store-brand'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style.copyWith(fontSize: size),
      );
    },
  );
  Widget _press({
    required Widget child,
    VoidCallback? onTap,
    Color color = Colors.transparent,
    double radius = 9,
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
    double minHeight = 44,
  }) => Material(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
  Widget _link(String text, VoidCallback action) => _press(
    onTap: action,
    minHeight: 36,
    padding: const EdgeInsets.fromLTRB(7, 7, 0, 7),
    child: Text(text, style: _type(12, color: reservationGold)),
  );
  Widget _heading(String title, {String? more}) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: _type(20, weight: FontWeight.w700, height: 1.3),
          ),
        ),
        if (more != null)
          _link(t('查看全部 ›|See all ›|查看全部 ›|ดูทั้งหมด ›'), () => _tab(more)),
      ],
    ),
  );
  Widget _block(List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
  Widget _empty(String text) => _loading
      ? const SizedBox.shrink()
      : Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xff1d1c1a),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: _type(13, color: _muted, height: 1.8),
          ),
        );
  void _infoSheet(String title, Widget child) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xff24221f),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (c) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 13, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xff615a50),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(title, style: _type(22, weight: FontWeight.w600)),
            const SizedBox(height: 14),
            child,
            const SizedBox(height: 18),
            _press(
              onTap: () => Navigator.pop(c),
              child: Center(
                heightFactor: 1,
                child: Text(
                  t('关闭|Close|關閉|ปิด'),
                  style: _type(13, color: _muted),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  void _hours() => _infoSheet(
    t('营业信息|Business hours|營業資訊|เวลาทำการ'),
    Text(
      _text(_store['hours']).isEmpty
          ? t(
              '商家尚未完善营业时间。活动时间请查看相应场次，预订可用时段请查看产品详情。|Business hours have not been provided. Check activity or booking details for available times.|商家尚未完善營業時間，請查看活動或預訂詳情。|ร้านยังไม่ระบุเวลาเปิด โปรดดูรายละเอียดกิจกรรมหรือการจอง',
            )
          : _text(_store['hours']),
      style: _type(14, color: _muted, height: 1.8),
    ),
  );
  void _gallery(Object? source, String title) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (c) => Scaffold(
        backgroundColor: _bg,
        appBar: kingAppBar(context: c, title: Text(title)),
        body: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: _image(source, width: double.infinity, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
  Widget _cover() => Container(
    key: const ValueKey('store-cover'),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff191611), _bg],
        stops: [0, .7],
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(.8, -1),
                radius: .85,
                colors: [Color(0x776e4e2a), Colors.transparent],
                stops: [0, .65],
              ),
            ),
          ),
        ),
        Positioned(
          right: -45,
          top: -90,
          child: Transform.rotate(
            angle: .45,
            child: Container(
              width: 255,
              height: 340,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(170),
                border: Border.all(color: const Color(0x2baa8654), width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0x10a17e37), spreadRadius: 35),
                  BoxShadow(color: Color(0x08a17e37), spreadRadius: 70),
                ],
              ),
            ),
          ),
        ),
        if (_text(_store['coverUrl']).isNotEmpty)
          Positioned.fill(child: _image(_store['coverUrl']))
        else
          Center(
            child: SizedBox.square(
              dimension: 164,
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0,
                  0,
                  0,
                  0,
                  255,
                  0,
                  0,
                  0,
                  0,
                  255,
                  0,
                  0,
                  0,
                  0,
                  255,
                  .2126,
                  .7152,
                  .0722,
                  0,
                  0,
                ]),
                child: _image(_store['logoUrl'], fit: BoxFit.contain),
              ),
            ),
          ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 17,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t(
                    '音乐 · 聚会 · 同城相遇|Music · Gather · Meet locally|音樂 · 聚會 · 同城相遇|ดนตรี · พบปะ',
                  ),
                  style: _type(11, color: const Color(0xffa99b87)),
                ),
              ),
              _press(
                onTap: () => _gallery(
                  _store['coverUrl'] ?? _store['logoUrl'],
                  t('店铺图集|Store gallery|店鋪圖集|รูปภาพร้าน'),
                ),
                radius: 14,
                minHeight: 28,
                color: const Color(0x77000000),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Text(
                  t('查看图集|Gallery|查看圖集|ดูรูป'),
                  style: _type(11, color: const Color(0xffded3c1)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _storeInfo() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          key: const ValueKey('store-identity'),
          children: [
            Container(
              key: const ValueKey('store-logo'),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xff302d28)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _image(
                _store['logoUrl'],
                height: 58,
                width: 58,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _brandLabel(),
                  if (_branch.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      _branch,
                      style: _type(
                        13,
                        color: const Color(0xffc1b8aa),
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (_hasActivities)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final label in [
                  t('同城交友活动|Local activities|同城交友活動|กิจกรรมใกล้คุณ'),
                  t('到店聚会|Meet in store|到店聚會|พบปะที่ร้าน'),
                ])
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff27231e),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      label,
                      style: _type(11, color: const Color(0xffc7b79e)),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                size: 15,
                color: reservationGold,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _text(_store['hours']).isEmpty
                      ? t(
                          '营业信息待完善|Hours not provided|營業資訊待完善|ยังไม่ระบุเวลาเปิด',
                        )
                      : _text(_store['hours']),
                  style: _type(12, color: const Color(0xffb4aea6), height: 1.7),
                ),
              ),
              _link(t('营业信息 ›|Hours ›|營業資訊 ›|เวลาเปิด ›'), _hours),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: reservationGold,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _text(_store['address']),
                  style: _type(12, color: const Color(0xffb4aea6), height: 1.7),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 17, bottom: 18),
          child: Row(
            children: [
              Expanded(
                child: _quick(
                  Icons.star_border,
                  _flag(_data?['favourite'])
                      ? t('已收藏|Saved|已收藏|บันทึกแล้ว')
                      : t('收藏店铺|Save store|收藏店鋪|บันทึกร้าน'),
                  _saving ? null : _favourite,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _quick(
                  Icons.chat_bubble_outline,
                  t('联系商家|Contact|聯絡商家|ติดต่อ'),
                  _contact,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _quick(
                  Icons.location_on_outlined,
                  t('到店导航|Directions|到店導航|เส้นทาง'),
                  _address,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _quick(IconData icon, String label, VoidCallback? onTap) => _press(
    onTap: onTap,
    color: const Color(0xff1d1c1a),
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: reservationGold),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: _type(12),
          ),
        ),
      ],
    ),
  );
  Widget _tabsView() => Container(
    key: const ValueKey('store-tabs'),
    decoration: const BoxDecoration(
      color: _bg,
      border: Border(bottom: BorderSide(color: Color(0xff282521))),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == 3 ? 0 : 30),
              child: InkWell(
                onTap: () => _tab(_tabs[i]),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _section == _tabs[i]
                            ? reservationGold
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    t(
                      [
                        '精选|Featured|精選|แนะนำ',
                        '活动|Activities|活動|กิจกรรม',
                        '订位|Booking|訂位|จอง',
                        '介绍|About|介紹|เกี่ยวกับ',
                      ][i],
                    ),
                    style: _type(
                      15,
                      color: _section == _tabs[i]
                          ? const Color(0xfff8f4ec)
                          : const Color(0xff94908b),
                      weight: _section == _tabs[i]
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  String _eventDate(Object? value) {
    final d = DateTime.tryParse('$value')?.toLocal();
    if (d == null) return '';
    return '${d.month}月${d.day}日 · ${['周一', '周二', '周三', '周四', '周五', '周六', '周日'][d.weekday - 1]}';
  }

  Widget _activity(Map<String, dynamic> row) {
    final ref = _text(row['ref']);
    final source = _text(row['image']);
    final kicker = _text(row['kicker']).isEmpty
        ? _eventDate(row['startsAt'])
        : _text(row['kicker']);
    final subtitle = _text(row['subtitle']).isNotEmpty
        ? _text(row['subtitle'])
        : switch (_text(row['feeMode'])) {
            'aa' => 'AA 制',
            'men_pay' => '男 A 女免',
            'host_treat' => '发起者请客 · 全免',
            _ => '',
          };
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Hero(
        tag: togetherActivityHeroTag(ref),
        createRectTween: togetherActivityRectTween,
        placeholderBuilder: togetherActivityPlaceholder,
        child: TogetherArtworkContrast(
          source: source.isEmpty ? null : source,
          aspectRatio: 2.24,
          textRegion: const Rect.fromLTRB(0, .55, .7, 1),
          builder: (context, ink) {
            final palette = TogetherFooterPalette(
              ink.flatFooter,
              translucent: true,
            );
            return ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Material(
                color: ink.flatFooter,
                child: InkWell(
                  onTap: widget.onActivity == null || _opening != null
                      ? null
                      : () => _openActivity(ref),
                  child: AspectRatio(
                    aspectRatio: 2.24,
                    child: Stack(
                      children: [
                        Positioned.fill(child: _image(row['image'])),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  ink.veil.withValues(alpha: .12),
                                ],
                                stops: const [.4, 1],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 104,
                          bottom: 12,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kicker,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _type(
                                  10,
                                  color: ink.editorialSecondary,
                                  weight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _text(row['title']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _type(
                                  15,
                                  color: ink.editorialPrimary,
                                  weight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _type(
                                  10,
                                  color: ink.editorialSecondary,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onActivity != null)
                          Positioned(
                            right: 14,
                            bottom: 7,
                            child: TogetherActivityAction(
                              palette: palette,
                              label: _seen.contains(ref) ? '加入' : '查看',
                              onPressed: _opening != null
                                  ? null
                                  : () => _openActivity(
                                      ref,
                                      join: _seen.contains(ref),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _voucher(Map<String, dynamic> row) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _press(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StoreVoucherDetailPage(
            storeRef: widget.storeRef,
            offerRef: _text(row['ref']),
            repository: _repository,
          ),
        ),
      ),
      radius: 18,
      color: const Color(0xff211f1b),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xff403629),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              color: Color(0xffe8d3ad),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(row['title']),
                  style: _type(16, weight: FontWeight.w700, height: 1.35),
                ),
                const SizedBox(height: 6),
                Text(
                  _text(row['subtitle']),
                  style: _type(12, color: const Color(0xffaaaaaa), height: 1.5),
                ),
                const SizedBox(height: 6),
                Text(
                  '${row['currency'] == 'CNY' ? '¥' : _text(row['currency'])}${reservationMoney(row['priceCents'] ?? '0')}',
                  style: _type(
                    21,
                    color: const Color(0xffe5cfaa),
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 24, color: Color(0xffaaaaaa)),
        ],
      ),
    ),
  );
  Widget _position(Map<String, dynamic> row) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: _press(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ReservationProductDetailPage(productRef: _text(row['ref'])),
        ),
      ),
      radius: 15,
      color: const Color(0xff22201d),
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _image(row['image'], width: 76, height: 76),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(row['title']),
                  style: _type(16, weight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '${reservationType(context, _text(row['type']))} · ${row['minimumSeats']}–${row['maximumSeats']} ${t('人|guests|人|คน')}',
                  style: _type(12, color: const Color(0xffa8a097), height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 20, color: Color(0xff82725f)),
        ],
      ),
    ),
  );
  Widget _about() => _block([
    _heading(t('认识这家店|About this store|認識這家店|เกี่ยวกับร้าน')),
    Text(
      _text(_store['introduction']).isEmpty
          ? t('商家尚未填写介绍|No introduction yet|商家尚未填寫介紹|ยังไม่มีข้อมูลแนะนำ')
          : _text(_store['introduction']),
      style: _type(14, color: const Color(0xffb5ada3), height: 1.85),
    ),
    const SizedBox(height: 14),
    Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () => _gallery(
                _store['coverUrl'] ?? _store['logoUrl'],
                t('品牌封面|Brand cover|品牌封面|ภาพปก'),
              ),
              child: Stack(
                children: [
                  _image(
                    _store['coverUrl'] ?? _store['logoUrl'],
                    height: 122,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                  Positioned(
                    left: 10,
                    bottom: 9,
                    child: Text(
                      t('品牌封面|Brand cover|品牌封面|ภาพปก'),
                      style: _type(11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            height: 122,
            decoration: BoxDecoration(
              color: const Color(0xff24211b),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              t('环境照片待完善|No venue photos yet|環境照片待完善|ยังไม่มีรูปสถานที่'),
              textAlign: TextAlign.center,
              style: _type(12, color: _muted),
            ),
          ),
        ),
      ],
    ),
    if (_section == 'about') ...[
      const SizedBox(height: 22),
      Text(
        _text(_store['hours']).isEmpty
            ? t('营业时间待商家完善|Hours not provided|營業時間待商家完善|ยังไม่ระบุเวลาเปิด')
            : _text(_store['hours']),
        style: _type(13, color: _muted, height: 1.7),
      ),
      const SizedBox(height: 12),
      Text(
        _text(_store['address']),
        style: _type(13, color: _muted, height: 1.7),
      ),
    ],
  ]);
  List<Widget> _sections() => [
    if (_section == 'featured' || _section == 'activities')
      _block([
        _heading(
          t('本店活动|Store activities|本店活動|กิจกรรมของร้าน'),
          more: _section == 'featured' ? 'activities' : null,
        ),
        if (_rows(_data?['activities']).isEmpty)
          _empty(t('本店暂未发布活动|No upcoming activities|本店暫未發佈活動|ยังไม่มีกิจกรรม'))
        else
          ..._rows(_data?['activities']).map(_activity),
      ]),
    if (_section == 'featured' || _section == 'vouchers')
      _block([
        _heading(
          t('团购券|Deals & vouchers|團購券|ดีลและคูปอง'),
          more:
              _section == 'featured' &&
                  _flag((_data?['more'] as Map?)?['vouchers'])
              ? 'vouchers'
              : null,
        ),
        if (_rows(_data?['vouchers']).isEmpty)
          _empty(
            t('本店暂无在售团购券|No vouchers on sale|本店暫無在售團購券|ยังไม่มีคูปองจำหน่าย'),
          )
        else
          ..._rows(_data?['vouchers']).map(_voucher),
      ]),
    if (_section == 'featured' || _section == 'booking')
      _block([
        _heading(
          t('选个位置|Choose a spot|選個位置|เลือกโต๊ะ'),
          more: _section == 'featured' ? 'booking' : null,
        ),
        Text(
          t(
            '约上朋友，提前安排今晚的相聚。|Make plans to meet your friends.|約上朋友，提前安排今晚的相聚。|นัดเพื่อนและวางแผนล่วงหน้า',
          ),
          style: _type(13, color: _muted, height: 1.6),
        ),
        const SizedBox(height: 15),
        if (_rows(_data?['products']).isEmpty)
          _empty(t('暂无可预订产品|No booking products|暫無可預訂產品|ยังไม่มีรายการจอง'))
        else
          ..._rows(_data?['products']).map(_position),
      ]),
    if (_section == 'featured' || _section == 'about') _about(),
    if (_section != 'featured' && _section != 'about')
      Row(
        children: [
          if (_page > 0)
            _link(
              t('上一页|Previous|上一頁|ก่อนหน้า'),
              () => _tab(_section, page: _page - 1),
            ),
          const Spacer(),
          if (_flag((_data?['more'] as Map?)?[_section]))
            _link(
              t('下一页|Next|下一頁|ถัดไป'),
              () => _tab(_section, page: _page + 1),
            ),
        ],
      ),
  ];
  Widget _bottom() => Container(
    key: const ValueKey('store-bottom'),
    decoration: const BoxDecoration(
      color: Color(0xff141310),
      border: Border(top: BorderSide(color: Color(0xff2e2a23))),
    ),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: _press(
              onTap: _contact,
              color: const Color(0xff2a2620),
              radius: 26,
              minHeight: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Center(
                heightFactor: 1,
                child: Text(
                  t('联系商家|Contact|聯絡商家|ติดต่อ'),
                  style: _type(
                    15,
                    color: const Color(0xffe4d8c5),
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _press(
              onTap: _flag(_store['canBook'])
                  ? _book
                  : _hasActivities
                  ? () => _tab('activities')
                  : null,
              color: _flag(_store['canBook']) || _hasActivities
                  ? reservationGold
                  : const Color(0xff2b2824),
              radius: 26,
              minHeight: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Center(
                heightFactor: 1,
                child: Text(
                  _flag(_store['canBook'])
                      ? t('选位置|Book a table|選位置|จองโต๊ะ')
                      : _hasActivities
                      ? t('查看活动|View activities|查看活動|ดูกิจกรรม')
                      : t('暂无可订位置|No bookings|暫無可訂位置|ยังไม่มีโต๊ะให้จอง'),
                  style: _type(
                    15,
                    color: _flag(_store['canBook']) || _hasActivities
                        ? const Color(0xff21190e)
                        : _muted,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    bottomNavigationBar: _data == null ? null : _bottom(),
    body: DefaultTextStyle(
      style: _type(14),
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              key: const ValueKey('store-cover-header'),
              pinned: true,
              toolbarHeight: 52,
              expandedHeight: (224 - MediaQuery.paddingOf(context).top)
                  .clamp(100, 224)
                  .toDouble(),
              backgroundColor: _bg,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              leadingWidth: 48,
              leading: KingBackButton(
                onPressed: () => Navigator.maybePop(context),
              ),
              title: LayoutBuilder(
                builder: (c, constraints) => AnimatedBuilder(
                  animation: _scroll,
                  builder: (c, _) => Opacity(
                    opacity: _scroll.hasClients && _scroll.offset > 120 ? 1 : 0,
                    child: Text(
                      _brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _type(17, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: () => _infoSheet(
                    t('分享这家店|Share store|分享這家店|แชร์ร้าน'),
                    Text(_text(_store['name']), style: _type(14)),
                  ),
                  icon: const Icon(
                    Icons.north_east,
                    size: 19,
                    color: Color(0xffded3c1),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              flexibleSpace: FlexibleSpaceBar(background: _cover()),
            ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _link(_error!, _load),
                ),
              ),
            if (_data != null) ...[
              SliverToBoxAdapter(child: _storeInfo()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StoreTabsHeader(
                  child: _tabsView(),
                  height: MediaQuery.textScalerOf(context).scale(15) > 19
                      ? 56
                      : 49,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                sliver: SliverList.list(children: _sections()),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _StoreTabsHeader extends SliverPersistentHeaderDelegate {
  const _StoreTabsHeader({required this.child, required this.height});
  final Widget child;
  final double height;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
  @override
  bool shouldRebuild(_StoreTabsHeader old) =>
      old.child != child || old.height != height;
}

class StoreVoucherDetailPage extends StatefulWidget {
  const StoreVoucherDetailPage({
    super.key,
    required this.storeRef,
    required this.offerRef,
    required this.repository,
  });
  final String storeRef, offerRef;
  final StoreHomeRepository repository;
  @override
  State<StoreVoucherDetailPage> createState() => _VoucherDetailState();
}

class _VoucherDetailState extends State<StoreVoucherDetailPage> {
  late Future<Map<String, dynamic>> _future = widget.repository.voucher(
    widget.storeRef,
    widget.offerRef,
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: kingAppBar(
      context: context,
      title: Text(
        reservationText(context, '团购券详情|Voucher details|團購券詳情|รายละเอียดคูปอง'),
      ),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (c, s) {
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => _future = widget.repository.voucher(
                  widget.storeRef,
                  widget.offerRef,
                ),
              ),
              child: Text(
                reservationText(
                  c,
                  '团购券暂不可用，点击重试|Voucher unavailable. Retry|團購券暫不可用，點擊重試|คูปองไม่พร้อม ลองอีกครั้ง',
                ),
              ),
            ),
          );
        }
        if (!s.hasData) return const SizedBox.expand();
        final v = s.data!['voucher'] as Map, store = s.data!['store'] as Map;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _text(v['title']),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              '${v['currency']} ${reservationMoney(v['priceCents'])}',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: reservationGold,
              ),
            ),
            const SizedBox(height: 24),
            for (final field in [
              ('适用门店|Store|適用門店|ร้านค้า', store['name']),
              ('包含内容|Contents|包含內容|รายการ', v['contents']),
              ('有效期|Validity|有效期|อายุใช้งาน', v['validity']),
              ('使用规则|Usage rules|使用規則|เงื่อนไขการใช้', v['usageRules']),
              ('退款规则|Refund rules|退款規則|เงื่อนไขคืนเงิน', v['refundRules']),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservationText(c, field.$1),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _text(field.$2),
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
            FilledButton(
              onPressed: null,
              child: Text(
                reservationText(
                  c,
                  '暂未开放购买|Purchase not available yet|暫未開放購買|ยังไม่เปิดให้ซื้อ',
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
