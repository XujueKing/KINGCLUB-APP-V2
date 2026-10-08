import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_input_style.dart';
import '../../../core/formatters/money.dart';
import '../data/reservation_products.dart';
import 'reservation_components.dart';

class ReservationProductsPage extends StatefulWidget {
  const ReservationProductsPage({
    super.key,
    required this.storeRef,
    this.call = callReservationProducts,
  });
  final String storeRef;
  final ReservationCall call;
  @override
  State<ReservationProductsPage> createState() => _ProductsState();
}

class _ProductsState extends State<ReservationProductsPage> {
  int _page = 0;
  late Future<Map<String, dynamic>> _future = _load();
  String? _busy, _error;
  final Map<String, String> _statusRequests = {};
  Future<Map<String, dynamic>> _load() => widget.call({
    'action': 'workspace',
    'storeRef': widget.storeRef,
    'page': _page,
  });
  Future<void> _edit(
    Map<String, dynamic> data,
    Map<String, dynamic>? product,
  ) async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ReservationProductEditorPage(
          workspace: data,
          product: product,
          call: widget.call,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _page = 0;
        _future = Future.value(updated);
      });
    }
  }

  Future<void> _status(Map<String, dynamic> product) async {
    final status = product['status'] == 'published' ? 'offline' : 'published';
    final key = '${product['ref']}:${product['version']}:$status';
    setState(() {
      _busy = product['ref'];
      _error = null;
    });
    try {
      final updated = await widget.call({
        'action': 'status',
        'storeRef': widget.storeRef,
        'productRef': product['ref'],
        'expectedVersion': product['version'],
        'status': status,
        'requestId': _statusRequests.putIfAbsent(key, () => const Uuid().v4()),
      });
      if (mounted) {
        setState(() {
          _page = 0;
          _future = Future.value(updated);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (c, s) => reservationScaffold(
      c,
      title: reservationText(c, '预订产品|Reservation products|預訂產品|รายการจอง'),
      body: s.hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: reservationButton(
                  reservationText(c, '重新加载|Retry|重新載入|ลองอีกครั้ง'),
                  () => setState(() => _future = _load()),
                ),
              ),
            )
          : !s.hasData
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  s.data!['store']['name'],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  reservationText(
                    c,
                    '发布散台、卡座和包厢。一个产品对应一个日期时段，顾客预订时选择实际编号位置。|Publish tables, booths and rooms for a specific date and time slot. Customers select a numbered position.|發布散台、卡座和包廂。一個產品對應一個日期時段，顧客預訂時選擇實際編號位置。|เผยแพร่โต๊ะ บูธ และห้องสำหรับช่วงวันที่และเวลา ลูกค้าเลือกหมายเลขที่นั่ง',
                  ),
                  style: const TextStyle(color: Colors.white60, height: 1.5),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                if (reservationRows(s.data!['products']).isEmpty)
                  reservationPanel(
                    Text(
                      reservationText(
                        c,
                        '暂无产品，新增后保存草稿，再确认上架。|No products yet. Save a draft, then publish it.|暫無產品，新增後保存草稿，再確認上架。|ยังไม่มีรายการ บันทึกฉบับร่างแล้วเผยแพร่',
                      ),
                    ),
                  ),
                for (final product in reservationRows(s.data!['products']))
                  reservationPanel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        reservationImage(product['image']),
                        const SizedBox(height: 16),
                        Text(
                          product['title'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        reservationRow(
                          reservationType(c, product['type']),
                          reservationText(c, switch (product['status']) {
                            'published' => '已上架|Published|已上架|เผยแพร่แล้ว',
                            'offline' => '已下架|Offline|已下架|ออฟไลน์',
                            _ => '草稿|Draft|草稿|ฉบับร่าง',
                          }),
                        ),
                        reservationRow(
                          reservationText(c, '到店时间|Arrival|到店時間|เวลาเข้า'),
                          reservationDate(product['startsAt']),
                        ),
                        reservationRow(
                          reservationText(c, '定金|Deposit|定金|มัดจำ'),
                          '${product['currency']} ${moneyCents(product['depositCents'])}',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: reservationButton(
                                reservationText(c, '编辑|Edit|編輯|แก้ไข'),
                                _busy == null
                                    ? () => _edit(s.data!, product)
                                    : null,
                                outline: true,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: reservationButton(
                                reservationText(
                                  c,
                                  product['status'] == 'published'
                                      ? '下架|Unpublish|下架|ยกเลิกเผยแพร่'
                                      : '上架|Publish|上架|เผยแพร่',
                                ),
                                _busy == null ? () => _status(product) : null,
                              ),
                            ),
                          ],
                        ),
                      ],
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
            ),
      bottom: !s.hasData
          ? null
          : reservationButton(
              reservationText(c, '新增预订产品|New product|新增預訂產品|เพิ่มรายการจอง'),
              _busy == null ? () => _edit(s.data!, null) : null,
            ),
    ),
  );
}

class ReservationProductEditorPage extends StatefulWidget {
  const ReservationProductEditorPage({
    super.key,
    required this.workspace,
    this.product,
    this.call = callReservationProducts,
  });
  final Map<String, dynamic> workspace;
  final Map<String, dynamic>? product;
  final ReservationCall call;
  @override
  State<ReservationProductEditorPage> createState() => _EditorState();
}

class _EditorState extends State<ReservationProductEditorPage> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.product?['title']);
  late final _description = TextEditingController(
    text: widget.product?['description'],
  );
  late final _deposit = TextEditingController(
    text: widget.product == null
        ? '0.00'
        : moneyUnits(
            widget.product!['depositCents'],
            precision: 2,
          ).replaceAll(',', ''),
  );
  late final _minimum = TextEditingController(
    text: widget.product == null
        ? '0.00'
        : moneyUnits(
            widget.product!['minimumSpendCents'],
            precision: 2,
          ).replaceAll(',', ''),
  );
  late final _minSeats = TextEditingController(
    text: '${widget.product?['minimumSeats'] ?? 1}',
  );
  late final _maxSeats = TextEditingController(
    text: '${widget.product?['maximumSeats'] ?? 4}',
  );
  late final _ref = widget.product?['ref'] ?? const Uuid().v4();
  late String _type = widget.product?['type'] ?? 'booth';
  late String? _artwork = widget.product?['artworkRef'];
  late final Set<String> _tables = Set<String>.from(
    widget.product?['tableRefs'] ?? [],
  );
  late DateTime _start = widget.product == null
      ? DateTime.now()
            .add(const Duration(days: 1))
            .copyWith(
              hour: 20,
              minute: 0,
              second: 0,
              millisecond: 0,
              microsecond: 0,
            )
      : DateTime.parse(widget.product!['startsAt']).toLocal();
  late DateTime _end = widget.product == null
      ? _start.add(const Duration(hours: 6))
      : DateTime.parse(widget.product!['endsAt']).toLocal();
  String? _error, _attempt, _request;
  bool _busy = false;
  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _deposit,
      _minimum,
      _minSeats,
      _maxSeats,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _time(bool start) async {
    final initial = start ? _start : _end;
    final first = DateTime.now().subtract(const Duration(days: 1));
    final last = DateTime.now().add(const Duration(days: 730));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : initial.isAfter(last)
          ? last
          : initial,
      firstDate: first,
      lastDate: last,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time != null && mounted) {
      setState(() {
        final value = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        if (start) {
          _start = value;
          if (!_end.isAfter(value)) _end = value.add(const Duration(hours: 6));
        } else {
          _end = value;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _busy) return;
    if (_tables.isEmpty ||
        _artwork == null ||
        !_end.isAfter(_start) ||
        _end.difference(_start) > const Duration(hours: 24) ||
        !_start.isAfter(DateTime.now()) ||
        int.parse(_maxSeats.text) < int.parse(_minSeats.text)) {
      setState(
        () => _error = reservationText(
          context,
          '请核对图片、位置、未来时段和人数|Check artwork, positions, future time slot and guest counts|請核對圖片、位置、未來時段和人數|ตรวจสอบภาพ ที่นั่ง ช่วงเวลาและจำนวนคน',
        ),
      );
      return;
    }
    final input = <String, dynamic>{
      'action': 'save',
      'storeRef': widget.workspace['store']['ref'],
      'productRef': _ref,
      'expectedVersion': widget.product?['version'] ?? 0,
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'type': _type,
      'artworkRef': _artwork,
      'tableRefs': _tables.toList()..sort(),
      'startsAt': _start.toUtc().toIso8601String(),
      'endsAt': _end.toUtc().toIso8601String(),
      'minimumSeats': int.parse(_minSeats.text),
      'maximumSeats': int.parse(_maxSeats.text),
      'depositCents': reservationAmountInput(_deposit.text),
      'minimumSpendCents': reservationAmountInput(_minimum.text),
    };
    final attempt = jsonEncode(input);
    if (attempt != _attempt) {
      _attempt = attempt;
      _request = const Uuid().v4();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.call({...input, 'requestId': _request});
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseArtwork() async {
    final artworks = reservationRows(widget.workspace['artworks']);
    final ref = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff202020),
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * .65,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  reservationText(
                    c,
                    '选择已审核封面|Approved cover|選擇已審核封面|เลือกภาพที่ผ่านอนุมัติ',
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    itemCount: artworks.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemBuilder: (c, i) => InkWell(
                      onTap: () => Navigator.pop(c, artworks[i]['ref']),
                      child: Column(
                        children: [
                          Expanded(
                            child: reservationImage(artworks[i]['image']),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            artworks[i]['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ref != null && mounted) setState(() => _artwork = ref);
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool amount = false,
    bool seats = false,
    int lines = 1,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          minLines: lines,
          maxLines: lines,
          maxLength: maxLength,
          enabled: !_busy,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          keyboardType: amount
              ? const TextInputType.numberWithOptions(decimal: true)
              : seats
              ? TextInputType.number
              : lines > 1
              ? TextInputType.multiline
              : TextInputType.text,
          inputFormatters: amount
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : seats
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          decoration: kingSearchDecoration(prefixIcon: null, counterText: ''),
          validator: (v) => amount
              ? reservationAmountInput(v ?? '') == null
                    ? reservationText(
                        context,
                        '输入有效金额|Enter valid amount|輸入有效金額|กรอกจำนวนที่ถูกต้อง',
                      )
                    : null
              : seats
              ? (int.tryParse(v ?? '') ?? 0) < 1 ||
                        (int.tryParse(v ?? '') ?? 0) > 1000
                    ? reservationText(
                        context,
                        '人数为1–1,000|Guests: 1–1,000|人數為1–1,000|จำนวนคน 1–1,000',
                      )
                    : null
              : (v ?? '').trim().isEmpty
              ? reservationText(context, '请填写|Required|請填寫|จำเป็น')
              : null,
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext c) => reservationScaffold(
    c,
    title: reservationText(
      c,
      '编辑预订产品|Edit reservation product|編輯預訂產品|แก้ไขรายการจอง',
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(c).bottom,
        ),
        children: [
          reservationPanel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.workspace['store']['name'],
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  children: ['table', 'booth', 'room']
                      .map(
                        (type) => ChoiceChip(
                          label: Text(reservationType(c, type)),
                          selected: type == _type,
                          onSelected: _busy
                              ? null
                              : (_) => setState(() => _type = type),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                _field(
                  _title,
                  reservationText(c, '产品名称|Product name|產品名稱|ชื่อรายการ'),
                  maxLength: 80,
                ),
                _field(
                  _description,
                  reservationText(
                    c,
                    '介绍与使用说明|Description and instructions|介紹與使用說明|รายละเอียดและคำแนะนำ',
                  ),
                  lines: 4,
                  maxLength: 4000,
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
                    '可预订位置|Bookable positions|可預訂位置|ที่นั่งที่จองได้',
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: reservationRows(widget.workspace['tables'])
                      .map(
                        (t) => FilterChip(
                          label: Text('${t['name']} · ${t['capacity']}'),
                          selected: _tables.contains(t['ref']),
                          onSelected: _busy
                              ? null
                              : (v) => setState(() {
                                  if (v) {
                                    _tables.add(t['ref']);
                                  } else {
                                    _tables.remove(t['ref']);
                                  }
                                }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _minSeats,
                        reservationText(c, '最少人数|Min. guests|最少人數|จำนวนต่ำสุด'),
                        seats: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _field(
                        _maxSeats,
                        reservationText(c, '最多人数|Max. guests|最多人數|จำนวนสูงสุด'),
                        seats: true,
                      ),
                    ),
                  ],
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(reservationText(c, '到店时间|Arrival|到店時間|เวลาเข้า')),
                  subtitle: Text(
                    reservationDate(_start.toUtc().toIso8601String()),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => _time(true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(reservationText(c, '结束时间|End|結束時間|เวลาสิ้นสุด')),
                  subtitle: Text(
                    reservationDate(_end.toUtc().toIso8601String()),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => _time(false),
                ),
              ],
            ),
          ),
          reservationPanel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(
                  _deposit,
                  reservationText(
                    c,
                    '预订定金（0为免费预订）|Deposit (0 for free booking)|預訂定金（0為免費預訂）|มัดจำ (0 สำหรับจองฟรี)',
                  ),
                  amount: true,
                ),
                _field(
                  _minimum,
                  reservationText(
                    c,
                    '最低消费（0为无最低消费）|Minimum spend (0 for none)|最低消費（0為無最低消費）|ยอดขั้นต่ำ (0 สำหรับไม่มีขั้นต่ำ)',
                  ),
                  amount: true,
                ),
                Text(
                  reservationText(
                    c,
                    '定金抵最终消费。取消退定金并释放位置，到店前不足4小时也适用。修改后保存草稿，不影响已成交预约。|Deposits offset the final bill. Cancellation refunds deposits and releases positions even within 4 hours. Saving changes creates a draft without altering previous reservations.|定金抵最終消費。取消退定金並釋放位置，到店前不足4小時也適用。修改後保存草稿，不影響已成交預約。|มัดจำหักบิลสุดท้าย ยกเลิกคืนมัดจำและที่นั่ง แม้ภายใน 4 ชั่วโมง การแก้ไขไม่เปลี่ยนการจองเดิม',
                  ),
                  style: const TextStyle(color: Colors.white60, height: 1.5),
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
                    '选择已审核封面|Approved cover|選擇已審核封面|เลือกภาพที่ผ่านอนุมัติ',
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                if (reservationRows(widget.workspace['artworks']).isEmpty)
                  Text(
                    reservationText(
                      c,
                      '暂无已审核图片|No approved artwork|暫無已審核圖片|ยังไม่มีภาพที่อนุมัติ',
                    ),
                  ),
                if (_artwork != null)
                  reservationImage(
                    reservationRows(widget.workspace['artworks'])
                        .where((a) => a['ref'] == _artwork)
                        .firstOrNull?['image'],
                    height: 160,
                  ),
                const SizedBox(height: 16),
                reservationButton(
                  reservationText(c, '选择封面|Choose cover|選擇封面|เลือกภาพปก'),
                  _busy || reservationRows(widget.workspace['artworks']).isEmpty
                      ? null
                      : _chooseArtwork,
                  outline: true,
                ),
              ],
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
      ),
    ),
    bottom: reservationButton(
      reservationText(
        c,
        _busy
            ? '保存中…|Saving…|保存中…|กำลังบันทึก…'
            : '保存草稿|Save draft|保存草稿|บันทึกฉบับร่าง',
      ),
      _busy ? null : _save,
    ),
  );
}
