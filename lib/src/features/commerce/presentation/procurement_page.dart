import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/procurement_repository.dart';

const _gold = Color(0xffcebea4), _panel = Color(0xff202020);
String procurementText(BuildContext c, List<String> values) {
  final l = Localizations.localeOf(c);
  return values[l.languageCode == 'en'
      ? 1
      : l.languageCode == 'th'
      ? 3
      : l.scriptCode == 'Hant' || {'TW', 'HK', 'MO'}.contains(l.countryCode)
      ? 2
      : 0];
}

String _money(dynamic cents) =>
    '¥${((cents as num? ?? 0) / 100).toStringAsFixed(2)}';
String _status(BuildContext c, dynamic status) =>
    procurementText(c, switch (status) {
      'pending' => ['待批准', 'Awaiting approval', '待批准', 'รออนุมัติ'],
      'approved' => ['待采购', 'Ready to buy', '待採購', 'พร้อมซื้อ'],
      'ordered' => ['待收货', 'Awaiting receipt', '待收貨', 'รอรับสินค้า'],
      'received' => ['已入库', 'Received', '已入庫', 'รับสินค้าแล้ว'],
      'draft' => ['已退回修改', 'Returned for changes', '已退回修改', 'ส่งกลับแก้ไข'],
      _ => ['已取消', 'Cancelled', '已取消', 'ยกเลิกแล้ว'],
    });
String _name(Map i) {
  final n = i['names'];
  return n is Map
      ? '${n['zh-CN'] ?? n['en'] ?? i['productRef']}'
      : '${i['productRef']}';
}

String _spec(Map i) {
  final v = i['specifications'];
  return v is Map ? '${v['zh-CN'] ?? v['en'] ?? ''}' : '';
}

class ProcurementPage extends StatefulWidget {
  const ProcurementPage({super.key, this.storeRef, this.batchRef, this.call});
  final String? storeRef, batchRef;
  final ProcurementCall? call;
  @override
  State<ProcurementPage> createState() => _ProcurementState();
}

class _ProcurementState extends State<ProcurementPage>
    with WidgetsBindingObserver {
  late final ProcurementCall call =
      widget.call ?? ProcurementRepository.secure().call;
  Map<String, dynamic>? data;
  String? store, error;
  bool loading = false, opened = false;
  int generation = 0;
  String filter = 'all';
  String t(List<String> v) => procurementText(context, v);
  @override
  void initState() {
    super.initState();
    store = widget.storeRef;
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    generation++;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      load();
    }
  }

  Future<void> load({bool more = false}) async {
    if (loading) return;
    final g = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final old = (data?['batches'] as List? ?? []);
      final result = await call({
        'action': 'context',
        'storeRef': ?store,
        if (more && old.isNotEmpty) 'before': old.last['rowId'],
      });
      if (!mounted || g != generation) return;
      setState(() {
        data = result;
        store = result['storeRef'] as String?;
        if (more) data!['batches'] = [...old, ...result['batches'] as List];
      });
      if (!opened && widget.batchRef != null && store != null) {
        opened = true;
        await open(widget.batchRef!);
      }
    } catch (e) {
      if (mounted && g == generation) {
        setState(
          () => error = e is AuthFailure
              ? e.message
              : t([
                  '读取失败，请重试',
                  'Could not load. Retry',
                  '讀取失敗，請重試',
                  'โหลดไม่สำเร็จ ลองอีกครั้ง',
                ]),
        );
      }
    } finally {
      if (mounted && g == generation) setState(() => loading = false);
    }
  }

  Future<void> open(String ref) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _BatchPage(
          call: call,
          store: store!,
          batch: ref,
          permissions: (data?['permissions'] as List? ?? []).cast<String>(),
        ),
      ),
    );
    if (changed == true && mounted) {
      // If opened by the initial context, defer until its loading guard is released.
      loading = false;
      await load();
    }
  }

  @override
  Widget build(BuildContext c) {
    final stores = data?['stores'] as List? ?? [],
        rows = data?['batches'] as List? ?? [];
    final visible = rows
        .where((r) => filter == 'all' || r['status'] == filter)
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xff111111),
      appBar: kingAppBar(
        context: c,
        centerTitle: true,
        title: Text(
          t(['门店采购', 'Store procurement', '門店採購', 'จัดซื้อร้าน']),
          style: const TextStyle(color: _gold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (stores.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  initialValue: store,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: stores
                      .map(
                        (s) => DropdownMenuItem(
                          value: s['storeRef'] as String,
                          child: Text('${s['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: loading
                      ? null
                      : (v) {
                          setState(() {
                            store = v;
                            data = null;
                          });
                          load();
                        },
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final s in [
                    'all',
                    'pending',
                    'approved',
                    'ordered',
                    'received',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        selected: filter == s,
                        label: Text(
                          s == 'all'
                              ? t(['全部', 'All', '全部', 'ทั้งหมด'])
                              : _status(c, s),
                        ),
                        onSelected: (_) => setState(() => filter = s),
                      ),
                    ),
                ],
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(onPressed: load, child: Text(error!)),
              ),
            Expanded(
              child: data == null && loading
                  ? const Center(child: CircularProgressIndicator())
                  : stores.isEmpty
                  ? Center(
                      child: Text(
                        t([
                          '暂无授权门店',
                          'No authorized stores',
                          '暫無授權門店',
                          'ไม่มีร้านที่ได้รับอนุญาต',
                        ]),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (visible.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                t([
                                  '暂无采购任务',
                                  'No procurement tasks',
                                  '暫無採購任務',
                                  'ไม่มีงานจัดซื้อ',
                                ]),
                              ),
                            ),
                          for (final r in visible)
                            Card(
                              color: _panel,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => open(r['batchRef'] as String),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${r['title']}',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _status(c, r['status']),
                                            style: const TextStyle(
                                              color: _gold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${r['batchNumber']} · ${r['applicationNumber'] ?? ''}',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              t([
                                                '${r['itemCount']} 项商品',
                                                '${r['itemCount']} items',
                                                '${r['itemCount']} 項商品',
                                                '${r['itemCount']} รายการ',
                                              ]),
                                            ),
                                          ),
                                          Text(
                                            _money(r['totalCostCents']),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (rows.length >= 30)
                            TextButton(
                              onPressed: loading
                                  ? null
                                  : () => load(more: true),
                              child: Text(
                                t([
                                  '更早批次',
                                  'Earlier batches',
                                  '更早批次',
                                  'ชุดก่อนหน้า',
                                ]),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchPage extends StatefulWidget {
  const _BatchPage({
    required this.call,
    required this.store,
    required this.batch,
    required this.permissions,
  });
  final ProcurementCall call;
  final String store, batch;
  final List<String> permissions;
  @override
  State<_BatchPage> createState() => _BatchState();
}

class _BatchState extends State<_BatchPage> {
  Map<String, dynamic>? data, retry;
  String? error;
  bool busy = false, changed = false;
  String t(List<String> v) => procurementText(context, v);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final r = await widget.call({
        'action': 'purchase_batch',
        'storeRef': widget.store,
        'batchRef': widget.batch,
      });
      if (mounted) {
        setState(() {
          data = r;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AuthFailure
              ? e.message
              : t(['读取失败', 'Could not load', '讀取失敗', 'โหลดไม่สำเร็จ']),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> act(Map<String, dynamic> action) async {
    final p =
        retry ??
        {
          'storeRef': widget.store,
          'batchRef': widget.batch,
          'revision': data!['revision'],
          'requestId': const Uuid().v4(),
          ...action,
        };
    setState(() {
      busy = true;
      error = null;
      retry = p;
    });
    try {
      final r = await widget.call(p);
      if (!mounted) return;
      final b = (r['receipt'] as Map?)?['batch'];
      if (b is! Map) {
        throw const AuthFailure('PROCUREMENT_RESPONSE_INVALID', '采购结果异常');
      }
      setState(() {
        data = Map<String, dynamic>.from(b);
        changed = true;
        retry = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AuthFailure
              ? e.message
              : t([
                  '操作结果未确认，请重试核对',
                  'Result unconfirmed. Retry to check',
                  '操作結果未確認，請重試核對',
                  'ผลยังไม่ยืนยัน ลองตรวจสอบอีกครั้ง',
                ]),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirmBuy() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          t(['确认已采购', 'Confirm purchased', '確認已採購', 'ยืนยันซื้อแล้ว']),
        ),
        content: Text(
          t([
            '按清单实际采购后确认，柜台会收到待收货批次。',
            'Confirm after buying this list. The counter will receive the delivery task.',
            '按清單實際採購後確認，櫃台會收到待收貨批次。',
            'ยืนยันหลังซื้อแล้ว เคาน์เตอร์จะได้รับงานรับสินค้า',
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t(['取消', 'Cancel', '取消', 'ยกเลิก'])),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t(['已采购', 'Purchased', '已採購', 'ซื้อแล้ว'])),
          ),
        ],
      ),
    );
    if (yes == true) await act({'action': 'purchase_batch_order'});
  }

  Future<void> attach() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              minTileHeight: 64,
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t(['拍摄凭证', 'Take a photo', '拍攝憑證', 'ถ่ายเอกสาร'])),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              minTileHeight: 64,
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                t(['选择凭证照片', 'Choose a photo', '選擇憑證照片', 'เลือกรูปเอกสาร']),
              ),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 65,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 1024 * 1024) {
        throw const AuthFailure('DOCUMENT_TOO_LARGE', '凭证照片不能超过 1MB');
      }
      final png = bytes.length >= 8 && bytes[0] == 137 && bytes[1] == 80;
      final result = await widget.call({
        'action': 'upload_document',
        'storeRef': widget.store,
        'name': image.name,
        'contentType': png ? 'image/png' : 'image/jpeg',
        'base64': base64Encode(bytes),
      });
      if (!mounted) return;
      final doc = data!['document'] as Map?;
      await act({
        'action': 'purchase_batch_document',
        'document': {
          'number': doc?['number'] ?? '',
          'fileIds': [...doc?['fileIds'] as List? ?? [], result['fileId']],
        },
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AuthFailure
              ? e.message
              : t([
                  '凭证未上传，请重试',
                  'Document upload failed. Retry',
                  '憑證未上傳，請重試',
                  'อัปโหลดเอกสารไม่สำเร็จ',
                ]),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final status = data?['status'], items = data?['items'] as List? ?? [];
    final review = widget.permissions.contains('cashbook.review'),
        buy = review || widget.permissions.contains('purchase.buy');
    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: const Color(0xff111111),
        appBar: kingAppBar(
          context: c,
          title: Text(t(['采购清单', 'Purchase list', '採購清單', 'รายการจัดซื้อ'])),
          leading: IconButton(
            onPressed: busy ? null : () => Navigator.pop(c, changed),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: data == null
            ? Center(
                child: error == null
                    ? const CircularProgressIndicator()
                    : TextButton(onPressed: load, child: Text(error!)),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          '${data!['title']}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${data!['batchNumber']}\n${data!['applicationNumber'] ?? ''}',
                          style: const TextStyle(
                            color: Colors.white60,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _status(c, status),
                          style: const TextStyle(color: _gold, fontSize: 18),
                        ),
                        const SizedBox(height: 20),
                        for (final i in items)
                          Card(
                            color: _panel,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_name(i as Map)} ${_spec(i)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${i['supplierName'] ?? i['supplierRef']}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${i['quantity']} × ${_money(i['unitCostCents'])}',
                                        ),
                                      ),
                                      Text(
                                        _money(
                                          (i['quantity'] as num) *
                                              (i['unitCostCents'] as num),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (status == 'ordered' ||
                                      status == 'received') ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      t([
                                        '已收 ${i['received']} / ${i['quantity']}',
                                        'Received ${i['received']} / ${i['quantity']}',
                                        '已收 ${i['received']} / ${i['quantity']}',
                                        'รับแล้ว ${i['received']} / ${i['quantity']}',
                                      ]),
                                    ),
                                    for (final l
                                        in i['locations'] as List? ?? [])
                                      Text(
                                        '${l['location']} · ${l['quantity']}',
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        Text(
                          t([
                            '合计 ${_money(items.fold<num>(0, (n, i) => n + (i['quantity'] as num) * (i['unitCostCents'] as num)))}',
                            'Total ${_money(items.fold<num>(0, (n, i) => n + (i['quantity'] as num) * (i['unitCostCents'] as num)))}',
                            '合計 ${_money(items.fold<num>(0, (n, i) => n + (i['quantity'] as num) * (i['unitCostCents'] as num)))}',
                            'รวม ${_money(items.fold<num>(0, (n, i) => n + (i['quantity'] as num) * (i['unitCostCents'] as num)))}',
                          ]),
                          style: const TextStyle(fontSize: 22, color: _gold),
                        ),
                        if (data!['note'] is String &&
                            (data!['note'] as String).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text('${data!['note']}'),
                          ),
                        if ([
                          'pending',
                          'approved',
                          'ordered',
                          'received',
                        ].contains(status))
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                              ),
                              onPressed:
                                  busy ||
                                      retry != null ||
                                      ((data!['document'] as Map?)?['fileIds']
                                                      as List? ??
                                                  [])
                                              .length >=
                                          8
                                  ? null
                                  : attach,
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: Text(
                                t([
                                  '补采购凭证（${((data!['document'] as Map?)?['fileIds'] as List? ?? []).length}/8）',
                                  'Add document (${((data!['document'] as Map?)?['fileIds'] as List? ?? []).length}/8)',
                                  '補採購憑證（${((data!['document'] as Map?)?['fileIds'] as List? ?? []).length}/8）',
                                  'เพิ่มเอกสาร (${((data!['document'] as Map?)?['fileIds'] as List? ?? []).length}/8)',
                                ]),
                              ),
                            ),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              error!,
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ),
                        if (status == 'ordered')
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Text(
                              t([
                                '请在柜台“收货入库”逐项验收并选择柜格，凭证可后补。',
                                'Receive each item and select its cabinet at the counter. Documents can be added later.',
                                '請在櫃台「收貨入庫」逐項驗收並選擇櫃格，憑證可後補。',
                                'รับสินค้าแต่ละรายการและเลือกตู้ที่เคาน์เตอร์ เพิ่มเอกสารภายหลังได้',
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          if (retry != null)
                            Expanded(
                              child: FilledButton(
                                onPressed: busy ? null : () => act(retry!),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                ),
                                child: Text(
                                  t([
                                    '重试核对',
                                    'Retry to check',
                                    '重試核對',
                                    'ลองตรวจสอบอีกครั้ง',
                                  ]),
                                ),
                              ),
                            )
                          else if (status == 'pending' && review) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => act({
                                        'action': 'purchase_batch_review',
                                        'approved': false,
                                      }),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                ),
                                child: Text(
                                  t(['退回修改', 'Return', '退回修改', 'ส่งกลับ']),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => act({
                                        'action': 'purchase_batch_review',
                                        'approved': true,
                                      }),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                ),
                                child: Text(
                                  t(['批准申请', 'Approve', '批准申請', 'อนุมัติ']),
                                ),
                              ),
                            ),
                          ] else if (status == 'approved' && buy)
                            Expanded(
                              child: FilledButton(
                                onPressed: busy ? null : confirmBuy,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                ),
                                child: Text(
                                  t([
                                    '确认已采购',
                                    'Confirm purchased',
                                    '確認已採購',
                                    'ยืนยันซื้อแล้ว',
                                  ]),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
