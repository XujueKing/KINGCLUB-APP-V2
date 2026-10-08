import 'dart:async';

import 'package:flutter/material.dart';

import '../data/reservation_deposits.dart';
import '../data/reservation_products.dart';
import 'reservation_components.dart';

/// Original-order query/cancellation only. New deposit sales remain server gated.
class ReservationDepositStatusPage extends StatefulWidget {
  const ReservationDepositStatusPage({
    super.key,
    required this.depositRef,
    this.initialResult,
    this.call = callReservationDeposit,
  });
  final String depositRef;
  final Map<String, dynamic>? initialResult;
  final ReservationCall call;
  @override
  State<ReservationDepositStatusPage> createState() => _DepositStatusState();
}

class _DepositStatusState extends State<ReservationDepositStatusPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false, _foreground = true;
  Timer? _timer;
  int _generation = 0;

  bool get _pending =>
      _data?['status'] == 'paying' ||
      (_data?['status'] == 'refund_pending' &&
          _data?['refund']?['status'] != 'review');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (widget.initialResult == null) {
      _read();
    } else {
      try {
        _data = reservationDepositResult(
          widget.initialResult!,
          widget.depositRef,
        );
        _schedule();
      } catch (e) {
        _error = e.toString();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _timer?.cancel();
    if (_foreground && _pending) _read(query: true);
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    if (_foreground && _pending && mounted) {
      _timer = Timer(const Duration(seconds: 10), () => _read(query: true));
    }
  }

  Future<void> _read({bool query = false, bool cancel = false}) async {
    if (_busy) return;
    final generation = ++_generation;
    _timer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.call({
        'action': query || cancel ? 'payment' : 'detail',
        'depositRef': widget.depositRef,
        if (query || cancel) 'operation': cancel ? 'cancel' : 'query',
      });
      if (!mounted || generation != _generation) return;
      final checked = reservationDepositResult(result, widget.depositRef);
      setState(() => _data = checked);
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        _schedule();
      }
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xff202020),
        title: Text(
          reservationText(c, '取消预约？|Cancel reservation?|取消預約？|ยกเลิกการจอง?'),
        ),
        content: Text(
          reservationText(
            c,
            '取消后释放位置，已付定金按原渠道退回。退款到账后会更新状态。|The position will be released. Paid deposits return through the original channel; the status updates after confirmation.|取消後釋放位置，已付定金按原渠道退回。退款到帳後會更新狀態。|คืนที่นั่งและคืนมัดจำผ่านช่องทางเดิม สถานะจะเปลี่ยนเมื่อยืนยันแล้ว',
          ),
        ),
        actions: [
          reservationButton(
            reservationText(c, '保留预约|Keep reservation|保留預約|เก็บการจองไว้'),
            () => Navigator.pop(c, false),
            outline: true,
          ),
          const SizedBox(height: 12),
          reservationButton(
            reservationText(c, '确认取消|Confirm cancellation|確認取消|ยืนยันยกเลิก'),
            () => Navigator.pop(c, true),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await _read(cancel: true);
  }

  String _status(
    BuildContext c,
  ) => reservationText(c, switch (_data?['status']) {
    'reserved' => '预约已确认|Reservation confirmed|預約已確認|ยืนยันการจองแล้ว',
    'arrived' => '已到店|Arrived|已到店|มาถึงร้านแล้ว',
    'closed' => '付款已关闭|Payment closed|付款已關閉|ปิดการชำระเงินแล้ว',
    'refunded' => '定金已退回|Deposit refunded|定金已退回|คืนมัดจำแล้ว',
    'refund_pending' =>
      _data?['refund']?['status'] == 'review'
          ? '退款需要核对|Refund needs review|退款需要核對|ต้องตรวจสอบการคืนเงิน'
          : '原渠道退款处理中|Refund in progress|原渠道退款處理中|กำลังคืนเงินผ่านช่องทางเดิม',
    _ => '付款核对中|Checking payment|付款核對中|กำลังตรวจสอบการชำระเงิน',
  });

  @override
  Widget build(BuildContext c) {
    final snap = _data == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(_data!['snapshot']);
    return reservationScaffold(
      c,
      title: reservationText(c, '预约定金|Reservation deposit|預約定金|มัดจำการจอง'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_data != null) ...[
            const SizedBox(height: 12),
            reservationPanel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _status(c),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(snap['storeName'], style: const TextStyle(fontSize: 18)),
                  if (snap['title'] is String) ...[
                    const SizedBox(height: 8),
                    Text(
                      snap['title'],
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  reservationRow(
                    reservationText(c, '位置|Position|位置|ที่นั่ง'),
                    snap['tableName'],
                  ),
                  reservationRow(
                    reservationText(c, '到店时间|Arrival|到店時間|เวลาเข้า'),
                    reservationDate(_data!['startsAt']),
                  ),
                  reservationRow(
                    reservationText(c, '人数|Guests|人數|จำนวนคน'),
                    '${_data!['partySize']}',
                  ),
                  reservationRow(
                    reservationText(c, '原定金|Original deposit|原定金|มัดจำเดิม'),
                    '${snap['currency']} ${reservationMoney(_data!['amountCents'])}',
                  ),
                  if (_data!['refund'] != null)
                    reservationRow(
                      reservationText(c, '退回金额|Refund amount|退回金額|ยอดคืนเงิน'),
                      '${snap['currency']} ${reservationMoney(_data!['refund']['amountCents'])}',
                    ),
                ],
              ),
            ),
            reservationPanel(
              Text(
                reservationText(
                  c,
                  _data!['status'] == 'paying'
                      ? '付款结果正在核对，位置尚未确认，请勿重复付款。|Payment is being checked; the position is not confirmed. Do not pay again.|付款結果正在核對，位置尚未確認，請勿重複付款。|กำลังตรวจสอบการชำระเงิน ยังไม่ยืนยันที่นั่ง อย่าชำระซ้ำ'
                      : _data!['status'] == 'refund_pending' &&
                            _data!['reservation'] == null
                      ? '本次未取得位置，已付定金按原渠道退回。|No position was secured. The paid deposit returns through the original channel.|本次未取得位置，已付定金按原渠道退回。|ไม่ได้รับที่นั่ง คืนมัดจำผ่านช่องทางเดิม'
                      : _data!['status'] == 'refund_pending'
                      ? '正在核对原渠道退款。点击核对原单查看进度，确认到账后会显示定金已退回。|The original-channel refund is being checked. Check the original order for progress; a confirmed refund will show as refunded.|正在核對原渠道退款。點擊核對原單查看進度，確認到帳後會顯示定金已退回。|กำลังตรวจสอบการคืนเงินผ่านช่องทางเดิม ตรวจสอบรายการเดิมเพื่อดูความคืบหน้า สถานะจะเปลี่ยนเมื่อยืนยันแล้ว'
                      : _data!['status'] == 'refunded'
                      ? '定金已按原支付渠道退回，本次定金流程已结束。|The deposit has been refunded through the original payment channel. This deposit flow is complete.|定金已按原支付渠道退回，本次定金流程已結束。|คืนมัดจำผ่านช่องทางเดิมแล้ว ขั้นตอนมัดจำนี้เสร็จสิ้น'
                      : _data!['status'] == 'closed'
                      ? '本次付款未完成，不占用位置。|Payment was not completed and no position is held.|本次付款未完成，不佔用位置。|ยังไม่ได้ชำระเงิน ไม่มีการจองที่นั่งไว้'
                      : '定金抵扣最终消费；未到店取消释放位置，按原渠道退款。|The deposit offsets the final bill. Cancellation before arrival releases the position and refunds the original channel.|定金抵扣最終消費；未到店取消釋放位置，按原渠道退款。|มัดจำหักจากยอดสุดท้าย ยกเลิกก่อนมาถึงจะคืนที่นั่งและคืนเงินผ่านช่องทางเดิม',
                ),
                style: const TextStyle(color: Colors.white70, height: 1.6),
              ),
            ),
          ],
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 16),
          ],
          reservationButton(
            reservationText(
              c,
              _busy
                  ? '核对中…|Checking…|核對中…|กำลังตรวจสอบ…'
                  : '核对原单|Check original order|核對原單|ตรวจสอบรายการเดิม',
            ),
            _busy ? null : () => _read(query: _data != null),
            outline: true,
          ),
        ],
      ),
      bottom: reservationFlag(_data?['canCancel'])
          ? reservationButton(
              reservationText(c, '取消预约|Cancel reservation|取消預約|ยกเลิกการจอง'),
              _busy ? null : _cancel,
              outline: true,
            )
          : null,
    );
  }
}
