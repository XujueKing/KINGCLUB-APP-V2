import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/party_allocation.dart';
import '../data/reservation_products.dart';
import 'reservation_components.dart';

class PartyAllocationPage extends StatefulWidget {
  const PartyAllocationPage({
    super.key,
    required this.storeRef,
    this.call = callPartyAllocation,
  });
  final String storeRef;
  final PartyAllocationCall call;
  @override
  State<PartyAllocationPage> createState() => _AllocationListState();
}

class _AllocationListState extends State<PartyAllocationPage> {
  int _page = 0;
  late Future<Map<String, dynamic>> _future = _load();
  Future<Map<String, dynamic>> _load() => widget.call({
    'action': 'workspace',
    'storeRef': widget.storeRef,
    'page': _page,
  });
  @override
  Widget build(BuildContext c) => reservationScaffold(
    c,
    title: reservationText(c, '活动分座|Activity seating|活動分座|จัดที่นั่งกิจกรรม'),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (c, s) {
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _future = _load()),
              child: Text(reservationText(c, '重试|Retry|重試|ลองอีกครั้ง')),
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final rows = reservationRows(s.data!['items']);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  reservationText(
                    c,
                    '暂无可安排的商家活动|No merchant activities to allocate|暫無可安排的商家活動|ยังไม่มีกิจกรรมให้จัดที่นั่ง',
                  ),
                ),
              ),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: reservationPanel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['theme']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        reservationDate(row['startsAt']),
                        style: const TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${row['tableCount']} ${reservationText(c, '桌|tables|桌|โต๊ะ')} · ${row['paidCount']} ${reservationText(c, '人已付款|paid guests|人已付款|คนชำระแล้ว')}',
                      ),
                      const SizedBox(height: 16),
                      reservationButton(
                        reservationText(c, '安排位置|Assign seats|安排位置|จัดที่นั่ง'),
                        () => Navigator.of(c).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PartyAllocationDetailPage(
                              storeRef: widget.storeRef,
                              partyRef: '${row['ref']}',
                              call: widget.call,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _page == 0
                      ? null
                      : () => setState(() {
                          _page--;
                          _future = _load();
                        }),
                  child: Text(reservationText(c, '上一页|Previous|上一頁|ก่อนหน้า')),
                ),
                TextButton(
                  onPressed: !reservationFlag(s.data!['hasMore'])
                      ? null
                      : () => setState(() {
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

class PartyAllocationDetailPage extends StatefulWidget {
  const PartyAllocationDetailPage({
    super.key,
    required this.storeRef,
    required this.partyRef,
    this.call = callPartyAllocation,
  });
  final String storeRef, partyRef;
  final PartyAllocationCall call;
  @override
  State<PartyAllocationDetailPage> createState() => _AllocationDetailState();
}

class _AllocationDetailState extends State<PartyAllocationDetailPage> {
  late Future<Map<String, dynamic>> _future = _load();
  Future<Map<String, dynamic>> _load() => widget.call({
    'action': 'detail',
    'storeRef': widget.storeRef,
    'partyRef': widget.partyRef,
  });
  final Set<String> _selected = {};
  final Map<String, String> _requests = {};
  String? _table, _error;
  bool _busy = false;
  Future<void> _assign() async {
    if (_busy || _table == null || _selected.isEmpty) return;
    final bookings = _selected.toList()..sort();
    final key = jsonEncode([_table, bookings]);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.call({
        'action': 'assign',
        'storeRef': widget.storeRef,
        'partyRef': widget.partyRef,
        'tableRef': _table,
        'bookingRefs': bookings,
        'requestId': _requests.putIfAbsent(key, () => const Uuid().v4()),
      });
      if (result['operation'] == null) throw StateError('未取得分座回执');
      if (mounted) {
        setState(() {
          _future = Future.value(result);
          _selected.clear();
          _requests.remove(key);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reservationText(
                context,
                '位置安排成功|Seats assigned|位置安排成功|จัดที่นั่งสำเร็จ',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (c, s) {
      final data = s.data,
          party = data?['party'] as Map?,
          tables = reservationRows(data?['tables']),
          members = reservationRows(data?['members']);
      final enabled =
          data != null && reservationFlag(party?['canAssign']) && !_busy;
      return reservationScaffold(
        c,
        title: reservationText(
          c,
          '活动分座|Activity seating|活動分座|จัดที่นั่งกิจกรรม',
        ),
        bottom: data == null
            ? null
            : reservationButton(
                _busy
                    ? reservationText(c, '正在确认…|Confirming…|正在確認…|กำลังยืนยัน…')
                    : reservationText(
                        c,
                        '确认安排|Confirm assignment|確認安排|ยืนยันที่นั่ง',
                      ),
                enabled && _table != null && _selected.isNotEmpty
                    ? _assign
                    : null,
              ),
        body: s.hasError
            ? Center(
                child: TextButton(
                  onPressed: () => setState(() => _future = _load()),
                  child: Text(reservationText(c, '重试|Retry|重試|ลองอีกครั้ง')),
                ),
              )
            : data == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '${party?['theme']}',
                    style: const TextStyle(fontSize: 22, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    reservationText(
                      c,
                      '选择已付款顾客，再选择预留位置。已核销的顾客不能调桌。|Select paid guests and a reserved table. Admitted guests cannot move.|選擇已付款顧客，再選擇預留位置。已核銷的顧客不能調桌。|เลือกแขกที่ชำระแล้วและโต๊ะที่จองไว้ แขกที่เข้างานแล้วย้ายไม่ได้',
                    ),
                    style: const TextStyle(color: Colors.white60, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  reservationPanel(
                    RadioGroup<String>(
                      groupValue: _table,
                      onChanged: (v) {
                        if (enabled) setState(() => _table = v);
                      },
                      child: Column(
                        children: [
                          for (final t in tables)
                            RadioListTile<String>(
                              value: '${t['ref']}',
                              enabled: enabled && reservationFlag(t['active']),
                              activeColor: const Color(0xffcebea4),
                              title: Text('${t['name']}'),
                              subtitle: Text(
                                '${t['assignedCount']} / ${t['capacity']} ${reservationText(c, '人|guests|人|คน')}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (members.isEmpty)
                    Text(
                      reservationText(
                        c,
                        '暂无已付款顾客|No paid guests yet|暫無已付款顧客|ยังไม่มีแขกที่ชำระเงิน',
                      ),
                    ),
                  reservationPanel(
                    Column(
                      children: [
                        for (final m in members)
                          CheckboxListTile(
                            key: ValueKey('guest-${m['bookingRef']}'),
                            value: _selected.contains(m['bookingRef']),
                            activeColor: const Color(0xffcebea4),
                            onChanged:
                                enabled && !reservationFlag(m['admitted'])
                                ? (checked) => setState(() {
                                    if (checked == true &&
                                        _selected.length < 100) {
                                      _selected.add('${m['bookingRef']}');
                                    }
                                    if (checked != true) {
                                      _selected.remove(m['bookingRef']);
                                    }
                                  })
                                : null,
                            title: Text('${m['nickname']}'),
                            subtitle: Text(
                              '${m['tableName'] ?? reservationText(c, '待分座|Unassigned|待分座|ยังไม่จัดที่นั่ง')}${reservationFlag(m['admitted']) ? ' · ${reservationText(c, '已入场|Admitted|已入場|เข้างานแล้ว')}' : ''}',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
      );
    },
  );
}
