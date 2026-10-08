import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/reservation_products.dart';
import 'reservation_components.dart';

String contractFundChannel(BuildContext c, Object? channel) =>
    reservationText(c, switch (channel) {
      'bank' => '银行转账|Bank transfer|銀行轉帳|โอนธนาคาร',
      'cash' => '现金|Cash|現金|เงินสด',
      'offline_wechat' => '线下微信|Offline WeChat|線下微信|WeChat ออฟไลน์',
      'offline_alipay' => '线下支付宝|Offline Alipay|線下支付寶|Alipay ออฟไลน์',
      'wechat' => 'APP微信支付|APP WeChat|APP微信支付|WeChat ในแอป',
      _ => '尚未收款|Not received|尚未收款|ยังไม่ได้รับ',
    });
String contractFundStatus(BuildContext c, Object? status) =>
    reservationText(c, switch (status) {
      'paying' => '付款核对中|Checking payment|付款核對中|กำลังตรวจชำระ',
      'paid' => '已收款|Received|已收款|ได้รับแล้ว',
      'refund_pending' =>
        '原渠道退回中|Returning to original channel|原渠道退回中|กำลังคืนช่องทางเดิม',
      'refunded' => '已退回|Returned|已退回|คืนแล้ว',
      _ => '待收款|Awaiting payment|待收款|รอชำระ',
    });

/// Records actual offline evidence; does not perform or invent a money transfer.
class ContractFundEvidencePage extends StatefulWidget {
  const ContractFundEvidencePage({
    super.key,
    required this.fund,
    required this.returning,
    required this.call,
  });
  final Map<String, dynamic> fund;
  final bool returning;
  final ReservationCall call;
  @override
  State<ContractFundEvidencePage> createState() => _ContractFundEvidenceState();
}

class _ContractFundEvidenceState extends State<ContractFundEvidencePage> {
  final _proof = TextEditingController();
  final _request = const Uuid().v4();
  String _channel = 'bank';
  bool _confirmed = false, _busy = false;
  String? _error;
  Map<String, dynamic>? _sent;
  @override
  void initState() {
    super.initState();
    if (widget.returning) _channel = '${widget.fund['channel']}';
  }

  @override
  void dispose() {
    _proof.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_confirmed || _proof.text.trim().length < 3) return;
    FocusManager.instance.primaryFocus?.unfocus();
    // Keep the exact evidence and timestamp when a response is uncertain.
    _sent ??= {
      'action': widget.returning ? 'record_return' : 'record_offline',
      'fundRef': widget.fund['ref'],
      'requestId': _request,
      'channel': _channel,
      'amountCents': reservationCents(widget.fund['amountCents']),
      'proofRef': _proof.text.trim(),
      'paidAt': DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
        isUtc: true,
      ).toIso8601String(),
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.call(_sent!);
      if (mounted) Navigator.pop(context, result);
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
      widget.returning
          ? '登记退款凭证|Record return evidence|登記退款憑證|บันทึกหลักฐานคืนเงิน'
          : '登记收款凭证|Record receipt evidence|登記收款憑證|บันทึกหลักฐานรับเงิน',
    ),
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(c).bottom + 24,
      ),
      children: [
        reservationPanel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CNY ${reservationMoney(widget.fund['amountCents'])}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              if (widget.returning)
                reservationRow(
                  reservationText(c, '原渠道|Original channel|原渠道|ช่องทางเดิม'),
                  contractFundChannel(c, _channel),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _channel,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xff303030),
                    border: InputBorder.none,
                  ),
                  items: ['bank', 'cash', 'offline_wechat', 'offline_alipay']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(contractFundChannel(c, v)),
                        ),
                      )
                      .toList(),
                  onChanged: _busy || _sent != null
                      ? null
                      : (v) => setState(() => _channel = v!),
                ),
              const SizedBox(height: 20),
              TextField(
                controller: _proof,
                readOnly: _sent != null,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff303030),
                  border: InputBorder.none,
                  hintText: reservationText(
                    c,
                    '流水号或凭证编号|Transaction or evidence reference|流水號或憑證編號|เลขธุรกรรมหรือหลักฐาน',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                reservationText(
                  c,
                  widget.returning
                      ? '须由原收取方完成原渠道退款后登记。登记不会代替实际退款。|Record only after the original collector returns the money through the original channel.|須由原收取方完成原渠道退款後登記。登記不會代替實際退款。|บันทึกเมื่อผู้รับเดิมคืนเงินจริงผ่านช่องทางเดิมแล้ว'
                      : '仅登记已经实际收到的款项，请核实准确金额和凭证。|Record only money actually received; verify the exact amount and evidence.|僅登記已經實際收到的款項，請核實準確金額和憑證。|บันทึกเงินที่รับจริง ตรวจจำนวนและหลักฐาน',
                ),
                style: const TextStyle(color: Colors.white60, height: 1.5),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmed,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _confirmed = v == true),
                title: Text(
                  reservationText(
                    c,
                    '已核实实际收退及凭证|Actual transfer and evidence verified|已核實實際收退及憑證|ตรวจเงินและหลักฐานแล้ว',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      ],
    ),
    bottom: reservationButton(
      reservationText(c, '确认登记|Confirm record|確認登記|ยืนยันบันทึก'),
      !_busy && _confirmed && _proof.text.trim().length >= 3 ? _save : null,
    ),
  );
}
