import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../data/monthly_contracts.dart';
import '../data/reservation_products.dart';
import 'reservation_components.dart';

String contractStatus(BuildContext c, Object? value) =>
    reservationText(c, switch (value) {
      'draft' => '草稿|Draft|草稿|ฉบับร่าง',
      'published' => '可领取|Available|可領取|รับได้',
      'active' => '已签约|Signed|已簽約|ลงนามแล้ว',
      _ => '已撤回|Withdrawn|已撤回|ถอนแล้ว',
    });

class MonthlyContractsPage extends StatefulWidget {
  const MonthlyContractsPage({super.key, this.storeRef, this.call});
  final String? storeRef;
  final ReservationCall? call;
  @override
  State<MonthlyContractsPage> createState() => _MonthlyContractsState();
}

class _MonthlyContractsState extends State<MonthlyContractsPage> {
  ReservationCall get call => widget.call ?? callMonthlyContracts;
  Map<String, dynamic>? _data;
  String? _error, _requestKey, _requestId;
  bool _busy = false;
  int _page = 0;
  bool get management => widget.storeRef != null;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await call({
        'action': management ? 'workspace' : 'mine',
        if (management) 'storeRef': widget.storeRef,
        'page': _page,
      });
      if (mounted) setState(() => _data = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mutate(Map<String, dynamic> contract, String action) async {
    final key = '$action:${contract['ref']}:${contract['version']}';
    if (_requestKey != key) {
      _requestKey = key;
      _requestId = const Uuid().v4();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await call({
        'action': action,
        'storeRef': widget.storeRef,
        'contractRef': contract['ref'],
        'expectedVersion': contract['version'],
        'requestId': _requestId,
      });
      if (mounted) {
        setState(() {
          _data = r;
          _page = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? contract]) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MonthlyContractEditorPage(
          workspace: _data!,
          storeRef: widget.storeRef!,
          contract: contract,
          call: call,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _data = result;
        _page = 0;
      });
    }
  }

  @override
  Widget build(BuildContext c) => reservationScaffold(
    c,
    title: reservationText(
      c,
      management
          ? '卡座签约任务|Table contract tasks|卡座簽約任務|งานสัญญาโต๊ะ'
          : '我的签约卡座|My contracted tables|我的簽約卡座|โต๊ะตามสัญญาของฉัน',
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          if (management && _data != null) ...[
            Text(_data!['store']['name'], style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 16),
            reservationButton(
              reservationText(
                c,
                '新增整月签约任务|New monthly contract|新增整月簽約任務|เพิ่มสัญญารายเดือน',
              ),
              _busy ? null : () => _edit(),
            ),
            const SizedBox(height: 20),
          ],
          for (final item in reservationRows(_data?['items']))
            reservationPanel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${item['storeName']} · ${item['tableName']} · ${item['month']}',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    contractStatus(c, item['status']),
                    style: const TextStyle(color: reservationGold),
                  ),
                  const SizedBox(height: 16),
                  reservationButton(
                    reservationText(c, '查看合同|View contract|查看合同|ดูสัญญา'),
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MonthlyContractDetailPage(
                          contractRef: item['ref'],
                          call: call,
                        ),
                      ),
                    ),
                  ),
                  if (management && item['status'] == 'draft') ...[
                    const SizedBox(height: 12),
                    reservationButton(
                      reservationText(c, '编辑条款|Edit terms|編輯條款|แก้ไขเงื่อนไข'),
                      _busy ? null : () => _edit(item),
                      outline: true,
                    ),
                    const SizedBox(height: 12),
                    reservationButton(
                      reservationText(
                        c,
                        '发布到任务大厅|Publish to task hall|發布到任務大廳|เผยแพร่ในศูนย์งาน',
                      ),
                      _busy ? null : () => _mutate(item, 'publish'),
                    ),
                  ],
                  if (management &&
                      ['draft', 'published'].contains(item['status'])) ...[
                    const SizedBox(height: 12),
                    reservationButton(
                      reservationText(c, '撤回任务|Withdraw task|撤回任務|ถอนงาน'),
                      _busy ? null : () => _mutate(item, 'withdraw'),
                      outline: true,
                    ),
                  ],
                ],
              ),
            ),
          if (_data != null && reservationRows(_data!['items']).isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  reservationText(
                    c,
                    '暂无签约卡座|No table contracts|暫無簽約卡座|ยังไม่มีสัญญาโต๊ะ',
                  ),
                ),
              ),
            ),
          if (_page > 0)
            reservationButton(
              reservationText(c, '上一页|Previous|上一頁|ก่อนหน้า'),
              _busy
                  ? null
                  : () {
                      _page--;
                      _load();
                    },
              outline: true,
            ),
          if (reservationFlag(_data?['hasMore']))
            reservationButton(
              reservationText(c, '下一页|Next|下一頁|ถัดไป'),
              _busy
                  ? null
                  : () {
                      _page++;
                      _load();
                    },
            ),
        ],
      ),
    ),
  );
}

class MonthlyContractEditorPage extends StatefulWidget {
  const MonthlyContractEditorPage({
    super.key,
    required this.workspace,
    required this.storeRef,
    required this.call,
    this.contract,
  });
  final Map<String, dynamic> workspace;
  final String storeRef;
  final ReservationCall call;
  final Map<String, dynamic>? contract;
  @override
  State<MonthlyContractEditorPage> createState() =>
      _MonthlyContractEditorState();
}

class _MonthlyContractEditorState extends State<MonthlyContractEditorPage> {
  late final _title = TextEditingController(
    text: widget.contract?['title'] ?? '',
  );
  late final _description = TextEditingController(
    text: widget.contract?['description'] ?? '',
  );
  late final _guarantee = TextEditingController(
    text: reservationMoney(widget.contract?['guaranteeCents'] ?? '0')
        .replaceAll(',', ''),
  );
  late final _contractAmount = TextEditingController(
    text: reservationMoney(widget.contract?['contractCents'] ?? '0')
        .replaceAll(',', ''),
  );
  late final _bookings = TextEditingController(
    text: '${widget.contract?['goalBookings'] ?? 0}',
  );
  late final _revenue = TextEditingController(
    text: reservationMoney(widget.contract?['goalRevenueCents'] ?? '0')
        .replaceAll(',', ''),
  );
  late final _rate = TextEditingController(
    text: widget.contract?['organizerBps'] == null
        ? ''
        : '${(widget.contract!['organizerBps'] as num) / 100}',
  );
  late String? _table = widget.contract?['tableRef'];
  late String _month = widget.contract?['month'] ?? _months.first,
      _collector = widget.contract?['collector'] ?? 'store',
      _mode = widget.contract?['goalMode'] ?? 'all';
  final _ref = const Uuid().v4();
  String? _error, _digest, _request;
  bool _busy = false;
  List<String> get _months => List.generate(24, (i) {
    final d = DateTime(DateTime.now().year, DateTime.now().month + i + 1);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  });
  @override
  void dispose() {
    for (final t in [
      _title,
      _description,
      _guarantee,
      _contractAmount,
      _bookings,
      _revenue,
      _rate,
    ]) {
      t.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool money = false,
    bool integer = false,
    int? maxLength,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextField(
      controller: controller,
      maxLength: maxLength,
      minLines: lines,
      maxLines: lines,
      keyboardType: money
          ? const TextInputType.numberWithOptions(decimal: true)
          : integer
          ? TextInputType.number
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      inputFormatters: integer
          ? [FilteringTextInputFormatter.digitsOnly]
          : money
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xff303030),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(lines > 1 ? 16 : 26),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(lines > 1 ? 16 : 26),
          borderSide: BorderSide.none,
        ),
        counterText: '',
      ),
    ),
  );
  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final g = reservationAmountInput(_guarantee.text),
        v = reservationAmountInput(_contractAmount.text),
        rev = reservationAmountInput(_revenue.text),
        b = int.tryParse(_bookings.text),
        percent = _rate.text.trim().isEmpty
            ? null
            : reservationAmountInput(_rate.text);
    if (_table == null ||
        _title.text.trim().isEmpty ||
        _description.text.trim().isEmpty ||
        g == null ||
        v == null ||
        rev == null ||
        b == null ||
        b < 0 ||
        b > 100000 ||
        (_rate.text.trim().isNotEmpty &&
            (percent == null || percent < 600 || percent > 2000)) ||
        ((g + v) > 0 && b == 0 && rev == 0)) {
      setState(
        () => _error = reservationText(
          context,
          '请填写位置、规则和有效目标；自定比例为6%–20%。|Complete the position, rules and valid targets; rate must be 6%–20%.|請填寫位置、規則和有效目標；自定比例為6%–20%。|ระบุโต๊ะ กฎ และเป้าหมาย อัตราต้อง 6%–20%',
        ),
      );
      return;
    }
    final p = <String, dynamic>{
      'action': 'save',
      'storeRef': widget.storeRef,
      'contractRef': widget.contract?['ref'] ?? _ref,
      'expectedVersion': widget.contract?['version'] ?? 0,
      'tableRef': _table,
      'month': _month,
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'guaranteeCents': g,
      'contractCents': v,
      'collector': _collector,
      'goalBookings': b,
      'goalRevenueCents': rev,
      'goalMode': _mode,
      'organizerBps': percent,
    };
    final digest = jsonEncode(p);
    if (_digest != digest) {
      _digest = digest;
      _request = const Uuid().v4();
    }
    p['requestId'] = _request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.call(p);
      if (mounted) Navigator.pop(context, r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => reservationScaffold(
    c,
    title: reservationText(
      c,
      '整月签约任务|Monthly table task|整月簽約任務|งานสัญญารายเดือน',
    ),
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(c).bottom + 100,
      ),
      children: [
        _field(
          reservationText(c, '任务名称|Task title|任務名稱|ชื่องาน'),
          _title,
          maxLength: 80,
        ),
        reservationPanel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reservationText(c, '编号位置|Numbered position|編號位置|โต๊ะที่ระบุ'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: reservationRows(widget.workspace['tables'])
                    .map(
                      (t) => ChoiceChip(
                        label: Text('${t['name']} · ${t['capacity']}'),
                        selected: _table == t['ref'],
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _table = t['ref']),
                      ),
                    )
                    .toList(),
              ),
              DropdownButtonFormField<String>(
                initialValue: _month,
                decoration: InputDecoration(
                  labelText: reservationText(
                    c,
                    '独占月份|Exclusive month|獨占月份|เดือนที่ผูกขาด',
                  ),
                ),
                items: ({_month, ..._months})
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: _busy ? null : (v) => setState(() => _month = v!),
              ),
              const SizedBox(height: 12),
              Text(
                '${reservationText(c, '门店时区|Store timezone|門店時區|เขตเวลาร้าน')} · ${widget.workspace['store']['timeZone']}',
                style: const TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
        _field(
          reservationText(
            c,
            '履约规则与介绍|Performance rules|履約規則與介紹|กฎการปฏิบัติงาน',
          ),
          _description,
          maxLength: 2000,
          lines: 4,
        ),
        _field(
          reservationText(
            c,
            '保证金（CNY，0为无保证金）|Guarantee (CNY, 0 for none)|保證金（CNY，0為無保證金）|เงินประกัน (CNY, 0 ไม่มี)',
          ),
          _guarantee,
          money: true,
        ),
        _field(
          reservationText(
            c,
            '承包资金（CNY）|Contract funds (CNY)|承包資金（CNY）|เงินสัญญา (CNY)',
          ),
          _contractAmount,
          money: true,
        ),
        reservationPanel(
          Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _collector,
                decoration: InputDecoration(
                  labelText: reservationText(
                    c,
                    '资金收取方|Fund collector|資金收取方|ผู้รับเงิน',
                  ),
                ),
                items: ['store', 'platform']
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          reservationText(
                            c,
                            s == 'store'
                                ? '商家|Merchant|商家|ร้านค้า'
                                : '平台|Platform|平台|แพลตฟอร์ม',
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _collector = v!),
              ),
              const SizedBox(height: 16),
              Text(
                reservationText(
                  c,
                  '保证金与承包资金分别记账，两项均按合同目标条件退回。有资金的签约支付正在接通，当前可先保存和发布条款。|Both funds are recorded separately and returned according to targets. Funded signing is being connected; terms can be saved and published.|保證金與承包資金分別記帳，兩項均按合同目標條件退回。有資金的簽約支付正在接通，當前可先保存和發布條款。|เงินทั้งสองบันทึกแยกกันและคืนตามเป้าหมาย กำลังเชื่อมการชำระเงินสัญญา บันทึกและเผยแพร่เงื่อนไขได้',
                ),
                style: const TextStyle(color: Colors.white60, height: 1.5),
              ),
            ],
          ),
        ),
        _field(
          reservationText(
            c,
            '有效订台次数目标（0不启用）|Valid table bookings target (0 disables)|有效訂台次數目標（0不啟用）|จำนวนจองที่สำเร็จ (0 ปิด)',
          ),
          _bookings,
          integer: true,
        ),
        _field(
          reservationText(
            c,
            '营业收入目标（CNY，0不启用）|Revenue target (CNY, 0 disables)|營業收入目標（CNY，0不啟用）|เป้ารายได้ (CNY, 0 ปิด)',
          ),
          _revenue,
          money: true,
        ),
        reservationPanel(
          Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _mode,
                decoration: InputDecoration(
                  labelText: reservationText(
                    c,
                    '目标达成条件|Target rule|目標達成條件|กฎเป้าหมาย',
                  ),
                ),
                items: ['all', 'any']
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          reservationText(
                            c,
                            s == 'all'
                                ? '所有启用目标均达成|All enabled targets|所有啟用目標均達成|ทุกเป้าหมาย'
                                : '任一启用目标达成|Any enabled target|任一啟用目標達成|เป้าหมายใดก็ได้',
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy ? null : (v) => setState(() => _mode = v!),
              ),
              const SizedBox(height: 16),
              Text(
                reservationText(
                  c,
                  '收入以已核销的微信、平台现金消费扣除退款计算；订台次数按已核销的不同编号活动场次计算，未付款、未入场不算。|Revenue is admitted WeChat/platform cash net of refunds; bookings count distinct admitted table events. Unpaid or unredeemed orders do not count.|收入以已核銷的微信、平台現金消費扣除退款計算；訂台次數按已核銷的不同編號活動場次計算，未付款、未入場不算。|รายได้คือเงิน WeChat/แพลตฟอร์มที่เข้างานแล้วหักคืนเงิน นับงานโต๊ะที่เข้างานแล้วเท่านั้น',
                ),
                style: const TextStyle(color: Colors.white60, height: 1.5),
              ),
            ],
          ),
        ),
        _field(
          reservationText(
            c,
            '带局比例（%，留空按等级）|Hosting rate (%, blank for level)|帶局比例（%，留空按等級）|อัตราเจ้าภาพ (%, ว่างตามระดับ)',
          ),
          _rate,
          money: true,
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      ],
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

class MonthlyContractDetailPage extends StatefulWidget {
  const MonthlyContractDetailPage({
    super.key,
    required this.contractRef,
    this.call,
  });
  final String contractRef;
  final ReservationCall? call;
  @override
  State<MonthlyContractDetailPage> createState() =>
      _MonthlyContractDetailState();
}

class _MonthlyContractDetailState extends State<MonthlyContractDetailPage> {
  ReservationCall get call => widget.call ?? callMonthlyContracts;
  Map<String, dynamic>? _item;
  String? _error, _request;
  bool _busy = false, _accepted = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await call({
        'action': 'detail',
        'contractRef': widget.contractRef,
      });
      if (mounted) setState(() => _item = reservationRows(r['items']).single);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim() async {
    if (!_accepted || _item == null) return;
    _request ??= const Uuid().v4();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await call({
        'action': 'claim',
        'contractRef': widget.contractRef,
        'requestId': _request,
        'expectedVersion': _item!['version'],
        'termsHash': _item!['termsHash'],
        'acceptedTerms': true,
      });
      if (mounted) setState(() => _item = reservationRows(r['items']).single);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final item = _item;
    return reservationScaffold(
      c,
      title: reservationText(c, '卡座签约合同|Table contract|卡座簽約合同|สัญญาโต๊ะ'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            TextButton(
              onPressed: _busy ? null : _load,
              child: Text(reservationText(c, '重新读取|Reload|重新讀取|โหลดใหม่')),
            ),
          ],
          if (item != null) ...[
            reservationPanel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('${item['storeName']} · ${item['tableName']}'),
                  const SizedBox(height: 12),
                  Text(
                    contractStatus(c, item['status']),
                    style: const TextStyle(color: reservationGold),
                  ),
                  reservationRow(
                    reservationText(
                      c,
                      '整月独占|Exclusive whole month|整月獨占|ผูกขาดทั้งเดือน',
                    ),
                    item['month'],
                  ),
                  reservationRow(
                    reservationText(c, '门店时区|Store timezone|門店時區|เขตเวลาร้าน'),
                    item['timeZone'],
                  ),
                  reservationRow(
                    reservationText(c, '保证金|Guarantee|保證金|เงินประกัน'),
                    'CNY ${reservationMoney(item['guaranteeCents'])}',
                  ),
                  reservationRow(
                    reservationText(c, '承包资金|Contract funds|承包資金|เงินสัญญา'),
                    'CNY ${reservationMoney(item['contractCents'])}',
                  ),
                  reservationRow(
                    reservationText(c, '收取方|Collector|收取方|ผู้รับเงิน'),
                    reservationText(
                      c,
                      item['collector'] == 'store'
                          ? '商家|Merchant|商家|ร้านค้า'
                          : '平台|Platform|平台|แพลตฟอร์ม',
                    ),
                  ),
                  reservationRow(
                    reservationText(c, '带局比例|Hosting rate|帶局比例|อัตราเจ้าภาพ'),
                    item['effectiveOrganizerBps'] != null
                        ? '${(item['effectiveOrganizerBps'] as num) / 100}%'
                        : item['organizerBps'] != null
                        ? '${(item['organizerBps'] as num) / 100}%'
                        : reservationText(
                            c,
                            '按签约时等级|Level at signing|按簽約時等級|ระดับเมื่อลงนาม',
                          ),
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
                      '履约目标与规则|Targets and rules|履約目標與規則|เป้าหมายและกฎ',
                    ),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 16),
                  if (item['goalBookings'] > 0)
                    reservationRow(
                      reservationText(
                        c,
                        '有效订台次数|Valid table bookings|有效訂台次數|จำนวนจองที่สำเร็จ',
                      ),
                      '${item['goalBookings']}',
                    ),
                  if (reservationCents(item['goalRevenueCents']) > 0)
                    reservationRow(
                      reservationText(
                        c,
                        '营业收入目标|Revenue target|營業收入目標|เป้ารายได้',
                      ),
                      'CNY ${reservationMoney(item['goalRevenueCents'])}',
                    ),
                  Text(
                    reservationText(
                      c,
                      item['goalMode'] == 'all'
                          ? '所有启用目标均需达成|All enabled targets required|所有啟用目標均需達成|ต้องครบทุกเป้าหมาย'
                          : '任一启用目标达成|Any enabled target required|任一啟用目標達成|ต้องครบเป้าหมายใดก็ได้',
                    ),
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item['description'],
                    style: const TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    reservationText(
                      c,
                      '保证金和承包资金分别记账，两项都按合同条件退回；不以月末到期自动视为完成。整月内只有签约合作者可发布该编号位置，商家预订和排位也检查独占条件。|Both funds are recorded separately and returned according to contract conditions, not automatically at month end. Only the signed partner publishes this position; reservations and assignments check exclusive rights.|保證金和承包資金分別記帳，兩項都按合同條件退回；不以月末到期自動視為完成。整月內只有簽約合作者可發布該編號位置，商家預訂和排位也檢查獨占條件。|เงินทั้งสองบันทึกแยกกันและคืนตามเงื่อนไข ไม่สำเร็จอัตโนมัติเมื่อสิ้นเดือน เฉพาะผู้ลงนามเผยแพร่โต๊ะนี้ การจองตรวจสิทธิ์ผูกขาดด้วย',
                    ),
                    style: const TextStyle(color: Colors.white60, height: 1.6),
                  ),
                ],
              ),
            ),
            if (item['status'] == 'published' &&
                (reservationCents(item['guaranteeCents']) > 0 ||
                    reservationCents(item['contractCents']) > 0))
              Text(
                reservationText(
                  c,
                  '签约收款与条件退款正在接通，当前不可支付签约。|Signing payment and conditional refunds are being connected. Funded signing is unavailable.|簽約收款與條件退款正在接通，當前不可支付簽約。|กำลังเชื่อมชำระและคืนเงินสัญญา ยังลงนามแบบชำระเงินไม่ได้',
                ),
                style: const TextStyle(color: reservationGold, height: 1.5),
              ),
            if (reservationFlag(item['canClaim']))
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _accepted,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _accepted = v == true),
                title: Text(
                  reservationText(
                    c,
                    '已阅读并同意本合同完整条款|I accept all contract terms|已閱讀並同意本合同完整條款|ยอมรับเงื่อนไขสัญญาทั้งหมด',
                  ),
                ),
              ),
          ],
        ],
      ),
      bottom: item != null && reservationFlag(item['canClaim'])
          ? reservationButton(
              reservationText(c, '领取并签约|Claim and sign|領取並簽約|รับงานและลงนาม'),
              !_busy && _accepted ? _claim : null,
            )
          : null,
    );
  }
}
