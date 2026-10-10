import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../data/procurement_repository.dart';
import 'procurement_page.dart' show procurementText;

/// Store-scoped listing work uses the existing member session and mobile API.
class ProductListingPage extends StatefulWidget {
  const ProductListingPage({super.key, this.storeRef, this.call});
  final String? storeRef;
  final ProcurementCall? call;
  @override
  State<ProductListingPage> createState() => _ProductListingState();
}

class _ProductListingState extends State<ProductListingPage> {
  late final call = widget.call ?? ProcurementRepository.secure().call;
  Map<String, dynamic>? data;
  String? store, error;
  bool busy = false, pendingOnly = true, needsRefresh = false;
  int generation = 0;
  String text(List<String> v) => procurementText(context, v);
  bool flag(dynamic v) => v == true || v == 1;
  bool get direct => flag((data?['listingPermissions'] as Map?)?['direct']);
  List<Map<String, dynamic>> rows(String key) => (data?[key] as List? ?? [])
      .whereType<Map>()
      .map((v) => Map<String, dynamic>.from(v))
      .toList();
  String name(dynamic value) =>
      value is Map ? '${value['zh-CN'] ?? value['en'] ?? ''}' : '';
  @override
  void initState() {
    super.initState();
    store = widget.storeRef;
    load();
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }

  Future<void> load() async {
    final g = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final v = await call({
        'action': 'listing_context',
        if (store != null) 'storeRef': store,
      });
      if (!mounted || g != generation) return;
      setState(() {
        data = v;
        store = v['storeRef'] as String?;
        needsRefresh = false;
      });
    } catch (_) {
      if (mounted && g == generation) {
        setState(
          () => error = text([
            '暂时无法读取，或没有本店商品管理权限',
            'Could not load or store permission is unavailable',
            '暫時無法讀取，或沒有本店商品管理權限',
            'อ่านไม่ได้หรือไม่มีสิทธิ์จัดการร้าน',
          ]),
        );
      }
    } finally {
      if (mounted && g == generation) setState(() => busy = false);
    }
  }

  Future<void> command(Map<String, dynamic> p) async {
    if (busy || needsRefresh || store == null) return;
    final g = generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final v = await call({
        ...p,
        'storeRef': store,
        'requestId': const Uuid().v4(),
      });
      if (!mounted || g != generation) return;
      setState(
        () => data = {...?data, ...v, 'requests': v['listingRequests'] ?? []},
      );
    } catch (_) {
      if (mounted && g == generation) {
        needsRefresh = true;
        setState(
          () => error = text([
            '操作未确认，请刷新查看结果；商品有变化时请退回重新提交',
            'Result not confirmed. Refresh; return changed products for resubmission',
            '操作未確認，請重新整理查看結果；商品有變化時請退回重新提交',
            'ยังยืนยันไม่ได้ กรุณารีเฟรชหรือส่งกลับเพื่อแก้ไข',
          ]),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = rows('products'), requests = rows('requests');
    final permissions = data?['listingPermissions'] as Map?;
    final stores = rows('stores');
    return Scaffold(
      appBar: AppBar(
        leading: KingBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(text(['商品上架', 'Product listing', '商品上架', 'จัดการจำหน่าย'])),
        actions: [
          IconButton(
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (stores.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DropdownButton<String>(
                isExpanded: true,
                value: store,
                items: [
                  for (final s in stores)
                    DropdownMenuItem(
                      value: '${s['storeRef']}',
                      child: Text('${s['name']}'),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        store = v;
                        data = null;
                        load();
                      },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text(
                      '${text(['待审批', 'Awaiting approval', '待審批', 'รออนุมัติ'])} (${requests.length})',
                    ),
                    selected: pendingOnly,
                    onSelected: busy
                        ? null
                        : (_) => setState(() => pendingOnly = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: Text(
                      text(['全部商品', 'All products', '全部商品', 'สินค้าทั้งหมด']),
                    ),
                    selected: !pendingOnly,
                    onSelected: busy
                        ? null
                        : (_) => setState(() => pendingOnly = false),
                  ),
                ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error!, style: const TextStyle(color: Colors.orange)),
            ),
          if (busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: data == null
                ? Center(
                    child: Text(
                      text([
                        '正在读取商品',
                        'Loading products',
                        '正在讀取商品',
                        'กำลังอ่านสินค้า',
                      ]),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      if (pendingOnly && requests.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Text(
                              text([
                                '没有待审批的申请',
                                'No pending applications',
                                '沒有待審批的申請',
                                'ไม่มีคำขอรออนุมัติ',
                              ]),
                            ),
                          ),
                        ),
                      if (pendingOnly)
                        for (final r in requests)
                          _requestCard(
                            r,
                            products,
                            flag(permissions?['review']),
                          ),
                      if (!pendingOnly)
                        for (final p in products)
                          _productCard(
                            p,
                            requests,
                            flag(permissions?['submit']),
                          ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(
    Map<String, dynamic> r,
    List<Map<String, dynamic>> products,
    bool review,
  ) {
    final p = products
        .where((p) => p['productRef'] == r['productRef'])
        .firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${name(p?['names'])} ${name(p?['specifications'])}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              flag(r['listed'])
                  ? text(['申请上架', 'Request to list', '申請上架', 'ขอเปิดขาย'])
                  : text(['申请下架', 'Request to delist', '申請下架', 'ขอปิดขาย']),
            ),
            Text('${r['submittedBy'] ?? ''}'),
            if (review)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy || needsRefresh
                            ? null
                            : () => command({
                                'action': 'review_listing',
                                'applicationRef': r['applicationRef'],
                                'approved': false,
                              }),
                        child: Text(text(['退回', 'Return', '退回', 'ส่งกลับ'])),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: busy || needsRefresh
                            ? null
                            : () => command({
                                'action': 'review_listing',
                                'applicationRef': r['applicationRef'],
                                'approved': true,
                              }),
                        child: Text(
                          text(['批准生效', 'Approve', '批准生效', 'อนุมัติ']),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _productCard(
    Map<String, dynamic> p,
    List<Map<String, dynamic>> requests,
    bool submit,
  ) {
    final pending = requests.any((r) => r['productRef'] == p['productRef']);
    return Card(
      child: SwitchListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text('${name(p['names'])} ${name(p['specifications'])}'),
        subtitle: Text(
          pending
              ? text([
                  '待手机审批，当前状态保持不变',
                  'Pending approval; current listing retained',
                  '待手機審批，目前狀態保持不變',
                  'รออนุมัติ สถานะปัจจุบันคงเดิม',
                ])
              : direct
              ? text([
                  '超级管理员直接操作',
                  'Superadministrator direct action',
                  '超級管理員直接操作',
                  'ผู้ดูแลดำเนินการโดยตรง',
                ])
              : text([
                  '修改后提交审批',
                  'Submit changes for approval',
                  '修改後提交審批',
                  'ส่งการแก้ไขเพื่ออนุมัติ',
                ]),
        ),
        value: flag(p['listed']),
        onChanged: busy || needsRefresh || pending || !submit
            ? null
            : (v) => command({
                'action': 'set_listing',
                'productRef': p['productRef'],
                'revision': p['revision'],
                'listed': v,
              }),
      ),
    );
  }
}
