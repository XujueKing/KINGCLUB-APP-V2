import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_input_style.dart';
import '../../home/data/home_city_catalog.dart';
import '../../home/presentation/home_city_page.dart';
import '../data/reservation_products.dart';
import '../data/reservation_deposits.dart';
import 'reservation_components.dart';
import 'reservation_deposit_status_page.dart';

class ReservationDiscoveryPage extends StatefulWidget {
  const ReservationDiscoveryPage({
    super.key,
    this.onBack,
    this.initialCity,
    this.cityCode,
    this.storeRef,
    this.tableRef,
    this.call = callReservationProducts,
  });
  final VoidCallback? onBack;
  final HomeCity? initialCity;
  final String? cityCode, storeRef, tableRef;
  final ReservationCall call;
  @override
  State<ReservationDiscoveryPage> createState() => _DiscoveryState();
}

class _DiscoveryState extends State<ReservationDiscoveryPage> {
  HomeCity? _city;
  Future<Map<String, dynamic>>? _future;
  String _type = 'all';
  int _page = 0;
  @override
  void initState() {
    super.initState();
    _city = widget.initialCity ?? HomeCitySession.current;
    _load();
  }

  void _load() {
    final code = widget.cityCode ?? _city?.code;
    _future = code == null
        ? null
        : widget.call({
            'action': 'catalog',
            'cityCode': code,
            if (widget.storeRef != null) 'storeRef': widget.storeRef,
            'type': _type,
            'page': _page,
          });
  }

  Future<void> _chooseCity() async {
    final catalog = await HomeCityCatalog.load();
    if (!mounted) return;
    final city = await Navigator.of(context).push<HomeCity>(
      MaterialPageRoute(
        builder: (_) => HomeCityPage(catalog: catalog, current: _city),
      ),
    );
    if (city != null && mounted) {
      setState(() {
        _city = city;
        _page = 0;
        _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => reservationScaffold(
    context,
    title: reservationText(context, '吃喝玩乐|Explore & book|吃喝玩樂|สำรวจและจอง'),
    onBack: widget.onBack,
    actions: [
      IconButton(
        tooltip: reservationText(
          context,
          '我的预约|My reservations|我的預約|การจองของฉัน',
        ),
        icon: const Icon(Icons.event_note_outlined),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MemberReservationsPage(call: widget.call),
          ),
        ),
      ),
    ],
    body: Column(
      children: [
        if (widget.cityCode == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _chooseCity,
                label: Text(
                  _city?.shortName ??
                      reservationText(
                        context,
                        '选择城市|Select city|選擇城市|เลือกเมือง',
                      ),
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: reservationGold,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: ['all', 'table', 'booth', 'room']
                .map(
                  (type) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Text(
                          type == 'all'
                              ? reservationText(context, '全部|All|全部|ทั้งหมด')
                              : reservationType(context, type),
                        ),
                        selected: type == _type,
                        onSelected: (_) => setState(() {
                          _type = type;
                          _page = 0;
                          _load();
                        }),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _future == null
              ? Center(
                  child: Text(
                    reservationText(
                      context,
                      '请先选择城市|Select a city first|請先選擇城市|เลือกเมืองก่อน',
                    ),
                  ),
                )
              : FutureBuilder<Map<String, dynamic>>(
                  future: _future,
                  builder: (c, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: reservationButton(
                            reservationText(c, '重新加载|Retry|重新載入|ลองอีกครั้ง'),
                            () => setState(_load),
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final result = snapshot.data!,
                        items = reservationRows(result['items']);
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Text(
                              reservationText(
                                c,
                                '暂无上架的预订产品|No reservation products yet|暫無上架的預訂產品|ยังไม่มีรายการจอง',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white60),
                            ),
                          ),
                        for (final item in items)
                          GestureDetector(
                            onTap: () async {
                              await Navigator.of(c).push(
                                MaterialPageRoute(
                                  builder: (_) => ReservationProductDetailPage(
                                    productRef: item['ref'],
                                    tableRef: widget.tableRef,
                                    call: widget.call,
                                  ),
                                ),
                              );
                              if (mounted) setState(_load);
                            },
                            child: reservationPanel(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  reservationImage(item['image']),
                                  const SizedBox(height: 16),
                                  Text(
                                    item['title'],
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${item['storeName']} · ${reservationType(c, item['type'])}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                  reservationRow(
                                    reservationText(
                                      c,
                                      '到店时间|Arrival|到店時間|เวลาเข้า',
                                    ),
                                    reservationDate(item['startsAt']),
                                  ),
                                  reservationRow(
                                    reservationText(
                                      c,
                                      '定金抵消费|Deposit offsets bill|定金抵消費|มัดจำหักค่าใช้จ่าย',
                                    ),
                                    reservationCents(item['depositCents']) == 0
                                        ? reservationText(
                                            c,
                                            '免费预订|Free booking|免費預訂|จองฟรี',
                                          )
                                        : '${item['currency']} ${reservationMoney(item['depositCents'])}',
                                  ),
                                  Text(
                                    reservationCents(
                                              item['minimumSpendCents'],
                                            ) ==
                                            0
                                        ? reservationText(
                                            c,
                                            '无最低消费|No minimum spend|無最低消費|ไม่มีขั้นต่ำ',
                                          )
                                        : '${reservationText(c, '最低消费|Minimum spend|最低消費|ขั้นต่ำ')} ${reservationMoney(item['minimumSpendCents'])}',
                                    style: const TextStyle(
                                      color: reservationGold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            if (_page > 0)
                              TextButton(
                                onPressed: () => setState(() {
                                  _page--;
                                  _load();
                                }),
                                child: Text(
                                  reservationText(
                                    c,
                                    '上一页|Previous|上一頁|ก่อนหน้า',
                                  ),
                                ),
                              ),
                            const Spacer(),
                            if (reservationFlag(result['hasMore']))
                              TextButton(
                                onPressed: () => setState(() {
                                  _page++;
                                  _load();
                                }),
                                child: Text(
                                  reservationText(c, '下一页|Next|下一頁|ถัดไป'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class ReservationProductDetailPage extends StatefulWidget {
  const ReservationProductDetailPage({
    super.key,
    required this.productRef,
    this.tableRef,
    this.call = callReservationProducts,
  });
  final String productRef;
  final String? tableRef;
  final ReservationCall call;
  @override
  State<ReservationProductDetailPage> createState() => _DetailState();
}

class _DetailState extends State<ReservationProductDetailPage> {
  late Future<Map<String, dynamic>> _future = widget.call({
    'action': 'detail',
    'productRef': widget.productRef,
  });
  final _name = TextEditingController();
  String? _table;
  int? _size;
  bool _accepted = false, _busy = false;
  String? _error;
  String? _attemptKey, _request;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _book(Map<String, dynamic> product) async {
    if (_busy) return;
    if (_name.text.trim().isEmpty || _table == null || !_accepted) {
      setState(
        () => _error = reservationText(
          context,
          '请选择位置、填写称呼并阅读规则|Select a position, enter your name and accept the rules|請選擇位置、填寫稱呼並閱讀規則|เลือกที่นั่ง กรอกชื่อและอ่านกฎ',
        ),
      );
      return;
    }
    final key = '${product['version']}|$_table|$_size|${_name.text.trim()}';
    if (key != _attemptKey) {
      _attemptKey = key;
      _request = const Uuid().v4();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.call({
        'action': 'book_free',
        'productRef': widget.productRef,
        'tableRef': _table,
        'requestId': _request,
        'expectedVersion': product['version'],
        'partySize': _size ?? product['minimumSeats'],
        'guestName': _name.text.trim(),
        'acceptedRules': true,
      });
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReservationReceiptPage(
            reservation: Map<String, dynamic>.from(result['reservation']),
            call: widget.call,
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (c, snapshot) {
      final items = snapshot.hasData
          ? reservationRows(snapshot.data!['items'])
          : <Map<String, dynamic>>[];
      final product = items.firstOrNull;
      if (product != null && _size == null) {
        _size = (product['minimumSeats'] as num).toInt();
      }
      final tables = product == null
          ? <Map<String, dynamic>>[]
          : reservationRows(product['tables']);
      if (_table == null &&
          widget.tableRef != null &&
          tables.any(
            (t) =>
                t['ref'] == widget.tableRef && reservationFlag(t['available']),
          )) {
        _table = widget.tableRef;
      }
      return reservationScaffold(
        c,
        title: reservationText(
          c,
          '预订详情|Reservation details|預訂詳情|รายละเอียดการจอง',
        ),
        body: snapshot.hasError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: reservationButton(
                    reservationText(c, '重新加载|Retry|重新載入|ลองอีกครั้ง'),
                    () => setState(
                      () => _future = widget.call({
                        'action': 'detail',
                        'productRef': widget.productRef,
                      }),
                    ),
                  ),
                ),
              )
            : product == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20 + MediaQuery.viewInsetsOf(c).bottom,
                ),
                children: [
                  reservationImage(product['image'], height: 190),
                  const SizedBox(height: 20),
                  Text(
                    product['title'],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product['storeName'],
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 20),
                  reservationPanel(
                    Column(
                      children: [
                        reservationRow(
                          reservationText(c, '到店时间|Arrival|到店時間|เวลาเข้า'),
                          reservationDate(product['startsAt']),
                        ),
                        reservationRow(
                          reservationText(c, '结束时间|End|結束時間|เวลาสิ้นสุด'),
                          reservationDate(product['endsAt']),
                        ),
                        reservationRow(
                          reservationText(c, '定金|Deposit|定金|มัดจำ'),
                          '${product['currency']} ${reservationMoney(product['depositCents'])}',
                        ),
                        reservationRow(
                          reservationText(c, '最低消费|Minimum spend|最低消費|ขั้นต่ำ'),
                          reservationCents(product['minimumSpendCents']) == 0
                              ? reservationText(
                                  c,
                                  '无最低消费|None|無最低消費|ไม่มีขั้นต่ำ',
                                )
                              : reservationMoney(product['minimumSpendCents']),
                        ),
                      ],
                    ),
                  ),
                  reservationPanel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reservationText(
                            c,
                            '选择位置|Select position|選擇位置|เลือกที่นั่ง',
                          ),
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: tables
                              .map(
                                (t) => ChoiceChip(
                                  label: Text(
                                    '${t['name']} · ${t['capacity']}',
                                  ),
                                  selected: _table == t['ref'],
                                  onSelected: reservationFlag(t['available'])
                                      ? (_) => setState(() => _table = t['ref'])
                                      : null,
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(reservationText(c, '人数|Guests|人數|จำนวนคน')),
                            const Spacer(),
                            IconButton(
                              onPressed: _size! > product['minimumSeats']
                                  ? () => setState(() => _size = _size! - 1)
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            Text('$_size'),
                            IconButton(
                              onPressed: _size! < product['maximumSeats']
                                  ? () => setState(() => _size = _size! + 1)
                                  : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        TextField(
                          controller: _name,
                          maxLength: 64,
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: kingSearchDecoration(
                            prefixIcon: null,
                            hintText: reservationText(
                              c,
                              '到店称呼|Guest name|到店稱呼|ชื่อผู้จอง',
                            ),
                            counterText: '',
                          ),
                        ),
                      ],
                    ),
                  ),
                  reservationPanel(
                    Text(
                      product['description'],
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.6,
                      ),
                    ),
                  ),
                  Text(
                    reservationText(
                      c,
                      '取消退定金并释放位置；到店前不足4小时取消也适用。定金抵最终消费，不重复扣费。|Cancellation refunds the deposit and releases the position, including within 4 hours. Deposits offset the final bill once.|取消退定金並釋放位置；到店前不足4小時取消也適用。定金抵最終消費，不重複扣費。|ยกเลิกคืนมัดจำและคืนที่นั่ง รวมถึงภายใน 4 ชั่วโมง มัดจำหักยอดบิลครั้งเดียว',
                    ),
                    style: const TextStyle(color: Colors.white60, height: 1.6),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _accepted,
                    onChanged: (v) => setState(() => _accepted = v == true),
                    title: Text(
                      reservationText(
                        c,
                        '已阅读预订与取消规则|I accept reservation and cancellation rules|已閱讀預訂與取消規則|อ่านกฎการจองและยกเลิกแล้ว',
                      ),
                    ),
                  ),
                  if (!reservationFlag(product['canBook']))
                    Text(
                      reservationText(
                        c,
                        (reservationCents(product['depositCents']) > 0)
                            ? '定金支付预订尚未开通，请联系门店。|Deposit bookings are not available yet. Contact the store.|定金支付預訂尚未開通，請聯繫門店。|การจองแบบมัดจำยังไม่เปิด กรุณาติดต่อร้าน'
                            : '此产品暂不可预订，请选择其他产品。|This product is unavailable. Choose another product.|此產品暫不可預訂，請選擇其他產品。|สินค้านี้ยังจองไม่ได้ กรุณาเลือกรายการอื่น',
                      ),
                      style: const TextStyle(color: reservationGold),
                    ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                ],
              ),
        bottom: product == null
            ? null
            : reservationButton(
                _busy
                    ? reservationText(c, '确认中…|Confirming…|確認中…|กำลังยืนยัน…')
                    : reservationText(
                        c,
                        reservationCents(product['depositCents']) > 0
                            ? '定金预订暂未开放|Deposit booking unavailable|定金預訂暫未開放|ยังไม่เปิดจองแบบมัดจำ'
                            : '确认免费预订|Confirm free reservation|確認免費預訂|ยืนยันการจองฟรี',
                      ),
                !_busy && reservationFlag(product['canBook'])
                    ? () => _book(product)
                    : null,
              ),
      );
    },
  );
}

class ReservationReceiptPage extends StatefulWidget {
  const ReservationReceiptPage({
    super.key,
    required this.reservation,
    this.call = callReservationProducts,
  });
  final Map<String, dynamic> reservation;
  final ReservationCall call;
  @override
  State<ReservationReceiptPage> createState() => _ReceiptState();
}

class _ReceiptState extends State<ReservationReceiptPage> {
  late Map<String, dynamic> _reservation = widget.reservation;
  bool _busy = false;
  String? _error;
  final _cancelRequest = const Uuid().v4();
  Future<void> _cancel() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          reservationText(c, '取消预约？|Cancel reservation?|取消預約？|ยกเลิกการจอง?'),
        ),
        content: Text(
          reservationText(
            c,
            '取消后释放位置。|The position will be released.|取消後釋放位置。|ที่นั่งจะถูกคืน',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(reservationText(c, '保留|Keep|保留|เก็บไว้')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(reservationText(c, '取消预约|Cancel|取消預約|ยกเลิก')),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.call({
        'action': 'cancel',
        'reservationRef': _reservation['ref'],
        'requestId': _cancelRequest,
      });
      if (mounted) {
        setState(
          () => _reservation = Map<String, dynamic>.from(result['reservation']),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final snap = Map<String, dynamic>.from(_reservation['snapshot']);
    final cancelled = _reservation['status'] == 'cancelled';
    return reservationScaffold(
      c,
      title: reservationText(c, '我的预约|My reservation|我的預約|การจองของฉัน'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          reservationPanel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  cancelled ? Icons.event_busy : Icons.event_available,
                  color: reservationGold,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  reservationText(
                    c,
                    cancelled
                        ? '已取消|Cancelled|已取消|ยกเลิกแล้ว'
                        : _reservation['status'] == 'arrived'
                        ? '已到店|Arrived|已到店|มาถึงร้านแล้ว'
                        : '预约已确认|Reservation confirmed|預約已確認|ยืนยันการจองแล้ว',
                  ),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(snap['storeName'], style: const TextStyle(fontSize: 18)),
                reservationRow(
                  reservationText(c, '位置|Position|位置|ที่นั่ง'),
                  snap['tableName'],
                ),
                reservationRow(
                  reservationText(c, '人数|Guests|人數|จำนวนคน'),
                  '${_reservation['partySize']}',
                ),
                reservationRow(
                  reservationText(c, '到店时间|Arrival|到店時間|เวลาเข้า'),
                  reservationDate(_reservation['startsAt']),
                ),
                reservationRow(
                  reservationText(c, '预订定金|Deposit|預訂定金|มัดจำ'),
                  '${snap['currency']} ${reservationMoney(snap['depositCents'])}',
                ),
              ],
            ),
          ),
          reservationPanel(
            Text(
              snap['description'] ?? '',
              style: const TextStyle(color: Colors.white70, height: 1.6),
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          if (!cancelled &&
              (reservationFlag(_reservation['canCancel']) ||
                  _reservation['status'] == 'reserved'))
            reservationButton(
              reservationText(
                c,
                _busy
                    ? '处理中…|Processing…|處理中…|กำลังดำเนินการ…'
                    : '取消预约|Cancel reservation|取消預約|ยกเลิกการจอง',
              ),
              _busy ? null : _cancel,
              outline: true,
            ),
        ],
      ),
    );
  }
}

class MemberReservationsPage extends StatefulWidget {
  const MemberReservationsPage({
    super.key,
    this.call = callReservationProducts,
    this.depositCall = callReservationDeposit,
  });
  final ReservationCall call;
  final ReservationCall depositCall;
  @override
  State<MemberReservationsPage> createState() => _MemberReservationsState();
}

class _MemberReservationsState extends State<MemberReservationsPage> {
  int _page = 0;
  late Future<Map<String, dynamic>> _future = _load();
  Future<Map<String, dynamic>> _load() =>
      widget.call({'action': 'reservations', 'page': _page});
  @override
  Widget build(BuildContext c) => reservationScaffold(
    c,
    title: reservationText(c, '我的预约|My reservations|我的預約|การจองของฉัน'),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (c, s) {
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _future = _load()),
              child: Text(reservationText(c, '重新加载|Retry|重新載入|ลองอีกครั้ง')),
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final items = reservationRows(s.data!['items']);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (items.isEmpty)
              Text(
                reservationText(c, '暂无预约|No reservations|暫無預約|ยังไม่มีการจอง'),
                textAlign: TextAlign.center,
              ),
            for (final row in items)
              InkWell(
                onTap: () async {
                  await Navigator.of(c).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          reservationCents(row['snapshot']['depositCents']) > 0
                          ? ReservationDepositStatusPage(
                              depositRef: row['ref'],
                              call: widget.depositCall,
                            )
                          : ReservationReceiptPage(
                              reservation: row,
                              call: widget.call,
                            ),
                    ),
                  );
                  if (mounted) setState(() => _future = _load());
                },
                child: reservationPanel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['snapshot']['storeName'],
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${row['snapshot']['title']} · ${row['snapshot']['tableName']}',
                      ),
                      reservationRow(
                        reservationDate(row['startsAt']),
                        reservationText(
                          c,
                          row['status'] == 'cancelled'
                              ? '已取消|Cancelled|已取消|ยกเลิกแล้ว'
                              : row['status'] == 'arrived'
                              ? '已到店|Arrived|已到店|มาถึงแล้ว'
                              : '已确认|Confirmed|已確認|ยืนยันแล้ว',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                if (_page > 0)
                  TextButton(
                    onPressed: () => setState(() {
                      _page--;
                      _future = _load();
                    }),
                    child: Text(
                      reservationText(c, '上一页|Previous|上一頁|ก่อนหน้า'),
                    ),
                  ),
                const Spacer(),
                if (reservationFlag(s.data!['hasMore']))
                  TextButton(
                    onPressed: () => setState(() {
                      _page++;
                      _future = _load();
                    }),
                    child: Text(reservationText(c, '下一页|Next|下一頁|ถัดไป')),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
