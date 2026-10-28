import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/media/cached_media_image.dart';
import '../../club/presentation/reservation_components.dart';
import '../../club/presentation/reservation_discovery_page.dart';
import '../data/store_home_repository.dart';

typedef StoreActivityOpen = Future<void> Function(
  BuildContext context,
  String ref,
);
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
  });
  final String storeRef;
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
  final _tabs = const ['featured', 'activities', 'booking', 'about'];
  String t(String value) => reservationText(context, value);
  Map get _store => _data?['store'] as Map? ?? {};
  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _openActivity(String ref) async {
    if (_opening != null || widget.onActivity == null) return;
    setState(() => _opening = ref);
    try {
      await widget.onActivity!(context, ref);
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

  Widget _heading(String title, {String? more}) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        if (more != null)
          TextButton(
            onPressed: () => _tab(more),
            child: Text(t('查看全部|See all|查看全部|ดูทั้งหมด')),
          ),
      ],
    ),
  );
  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white54, height: 1.5),
    ),
  );
  Widget _activity(Map<String, dynamic> row) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: const Color(0xff211f1b),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onActivity == null || _opening != null
            ? null
            : () => _openActivity(_text(row['ref'])),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 1.8, child: _image(row['image'])),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text(row['title']),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reservationDate(row['startsAt']),
                    style: const TextStyle(fontSize: 13, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _voucher(Map<String, dynamic> row) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: const Color(0xff211f1b),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StoreVoucherDetailPage(
              storeRef: widget.storeRef,
              offerRef: _text(row['ref']),
              repository: _repository,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xff403629),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: reservationGold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(row['title']),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _text(row['subtitle']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_text(row['currency'])} ${reservationMoney(row['priceCents'] ?? '0')}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: reservationGold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _position(Map<String, dynamic> row) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: const Color(0xff211f1b),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _image(row['image'], height: 64, width: 64),
        ),
        title: Text(_text(row['title'])),
        subtitle: Text(
          '${reservationType(context, _text(row['type']))} · ${row['minimumSeats']}–${row['maximumSeats']} ${t('人|guests|人|คน')}',
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ReservationProductDetailPage(productRef: _text(row['ref'])),
          ),
        ),
      ),
    ),
  );
  Widget _about() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(t('认识这家店|About this store|認識這家店|เกี่ยวกับร้าน')),
      Text(
        _text(_store['introduction']).isEmpty
            ? t('商家尚未填写介绍|No introduction yet|商家尚未填寫介紹|ยังไม่มีข้อมูลแนะนำ')
            : _text(_store['introduction']),
        style: const TextStyle(color: Colors.white70, height: 1.6),
      ),
      const SizedBox(height: 18),
      Text(
        _text(_store['hours']).isEmpty
            ? t('营业时间待商家完善|Hours not provided|營業時間待商家完善|ยังไม่ระบุเวลาเปิด')
            : _text(_store['hours']),
        style: const TextStyle(color: Colors.white54),
      ),
      const SizedBox(height: 12),
      Text(
        _text(_store['address']),
        style: const TextStyle(color: Colors.white70, height: 1.5),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: kingAppBar(
      context: context,
      title: Text(
        _text(_store['name']).isEmpty
            ? t('店铺|Store|店鋪|ร้านค้า')
            : _text(_store['name']),
      ),
    ),
    bottomNavigationBar: _data == null
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _contact,
                      child: Text(t('联系商家|Contact|聯絡商家|ติดต่อ')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _flag(_store['canBook']) ? _book : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: reservationGold,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(
                        _flag(_store['canBook'])
                            ? t('选位置|Book a table|選位置|จองโต๊ะ')
                            : t('暂无可订位置|No bookings|暫無可訂位置|ยังไม่มีโต๊ะให้จอง'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(28),
              child: TextButton(onPressed: _load, child: Text(_error!)),
            ),
          if (_data != null) ...[
            Stack(
              alignment: Alignment.bottomLeft,
              children: [
                _image(
                  _store['coverUrl'] ?? _store['logoUrl'],
                  height: 220,
                  width: double.infinity,
                  fit: _store['coverUrl'] == null
                      ? BoxFit.contain
                      : BoxFit.cover,
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _image(_store['logoUrl'], height: 64, width: 64),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(_store['brandName']).isEmpty
                              ? _text(_store['name'])
                              : _text(_store['brandName']),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_text(_store['branchName']).isNotEmpty)
                          Text(
                            _text(_store['branchName']),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white60,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _text(_store['address']),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.white60,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _saving ? null : _favourite,
                      icon: Icon(
                        _flag(_data?['favourite'])
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 19,
                      ),
                      label: Text(
                        _flag(_data?['favourite'])
                            ? t('已收藏|Saved|已收藏|บันทึกแล้ว')
                            : t('收藏|Save|收藏|บันทึก'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _contact,
                      icon: const Icon(Icons.chat_bubble_outline, size: 19),
                      label: Text(t('联系|Contact|聯絡|ติดต่อ')),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _address,
                      icon: const Icon(Icons.near_me_outlined, size: 19),
                      label: Text(t('地址|Address|地址|ที่อยู่')),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_data != null || _loading)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    TextButton(
                      onPressed: () => _tab(_tabs[i]),
                      child: Text(
                        t(
                          [
                            '精选|Featured|精選|แนะนำ',
                            '活动|Activities|活動|กิจกรรม',
                            '订位|Booking|訂位|จอง',
                            '介绍|About|介紹|เกี่ยวกับ',
                          ][i],
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _section == _tabs[i]
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: _section == _tabs[i]
                              ? Colors.white
                              : Colors.white54,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (_data != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_section == 'featured' || _section == 'activities') ...[
                    _heading(
                      t('本店活动|Store activities|本店活動|กิจกรรมของร้าน'),
                      more: _section == 'featured' ? 'activities' : null,
                    ),
                    if (_rows(_data?['activities']).isEmpty)
                      _empty(
                        t(
                          '本店暂未发布活动|No upcoming activities|本店暫未發佈活動|ยังไม่มีกิจกรรม',
                        ),
                      )
                    else
                      ..._rows(_data?['activities']).map(_activity),
                  ],
                  if (_section == 'featured' || _section == 'vouchers') ...[
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
                        t(
                          '本店暂无在售团购券|No vouchers on sale|本店暫無在售團購券|ยังไม่มีคูปองจำหน่าย',
                        ),
                      )
                    else
                      ..._rows(_data?['vouchers']).map(_voucher),
                  ],
                  if (_section == 'featured' || _section == 'booking') ...[
                    _heading(
                      t('选个位置|Choose a spot|選個位置|เลือกโต๊ะ'),
                      more: _section == 'featured' ? 'booking' : null,
                    ),
                    if (_rows(_data?['products']).isEmpty)
                      _empty(
                        t(
                          '暂无可预订产品|No booking products|暫無可預訂產品|ยังไม่มีรายการจอง',
                        ),
                      )
                    else
                      ..._rows(_data?['products']).map(_position),
                  ],
                  if (_section == 'featured' || _section == 'about') _about(),
                  if (_section != 'featured' && _section != 'about')
                    Row(
                      children: [
                        if (_page > 0)
                          TextButton(
                            onPressed: () => _tab(_section, page: _page - 1),
                            child: Text(t('上一页|Previous|上一頁|ก่อนหน้า')),
                          ),
                        const Spacer(),
                        if (_flag((_data?['more'] as Map?)?[_section]))
                          TextButton(
                            onPressed: () => _tab(_section, page: _page + 1),
                            child: Text(t('下一页|Next|下一頁|ถัดไป')),
                          ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
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
