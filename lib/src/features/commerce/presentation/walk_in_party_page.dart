import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/king_components.dart';
import '../data/ordering_table_repository.dart';
import 'ordering_entry_status.dart';

class WalkInPartyPage extends StatefulWidget {
  const WalkInPartyPage({
    super.key,
    required this.entry,
    required this.locale,
    required this.onBack,
    required this.onConfirm,
    required this.onRefresh,
  });
  final OrderingEntryRequired entry;
  final Locale locale;
  final VoidCallback onBack, onRefresh;
  final Future<void> Function(int) onConfirm;
  @override
  State<WalkInPartyPage> createState() => _WalkInPartyPageState();
}

class _WalkInPartyPageState extends State<WalkInPartyPage> {
  final _more = TextEditingController();
  int? _selected;
  bool _custom = false, _busy = false;
  String? _error;
  String t(List<String> text) => OrderingEntryStatus.text(widget.locale, text);
  @override
  void dispose() {
    _more.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy) return;
    final count = _custom ? int.tryParse(_more.text) : _selected;
    if (count == null || count < widget.entry.minimumPeople || count > 65535) {
      setState(
        () => _error =
            '${t(['请选择有效人数，至少', 'Choose guests, at least', '請選擇有效人數，至少', 'เลือกจำนวนคนอย่างน้อย'])} ${widget.entry.minimumPeople}',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm(count);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: kingAppBar(
      context: context,
      leading: KingBackButton(onPressed: widget.onBack),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              color: const Color(0xff211e18),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t(
                              widget.entry.staffRequired
                                  ? [
                                      '请联系预订人员',
                                      'Contact reservation staff',
                                      '請聯繫預訂人員',
                                      'กรุณาติดต่อพนักงานจอง',
                                    ]
                                  : [
                                      '客官，您几位？',
                                      'How many guests?',
                                      '客官，您幾位？',
                                      'มากี่ท่าน?',
                                    ],
                            ),
                            style: const TextStyle(fontSize: 21),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.entry.tableName,
                            textAlign: TextAlign.end,
                            style: const TextStyle(color: Color(0xffc7b69b)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (widget.entry.staffRequired) ...[
                      Text(
                        t([
                          '本桌由预订人员确认套餐或预约后开台。',
                          'Staff will open this table after confirming the package or reservation.',
                          '本桌由預訂人員確認套餐或預約後開台。',
                          'พนักงานจะเปิดโต๊ะหลังยืนยันแพ็กเกจหรือการจอง',
                        ]),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: widget.onRefresh,
                        child: Text(t(['刷新', 'Refresh', '重新整理', 'รีเฟรช'])),
                      ),
                    ] else ...[
                      for (final start in [1, 5, 9])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              for (
                                int n = start;
                                n < start + (start == 9 ? 2 : 4);
                                n++
                              )
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: SizedBox(
                                      height: 52,
                                      child: TextButton(
                                        style: TextButton.styleFrom(
                                          backgroundColor:
                                              !_custom && _selected == n
                                              ? const Color(0xffc7b69b)
                                              : const Color(0xff343027),
                                          foregroundColor:
                                              !_custom && _selected == n
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                        onPressed: _busy
                                            ? null
                                            : () => setState(() {
                                                _selected = n;
                                                _custom = false;
                                                _error = null;
                                              }),
                                        child: Text(
                                          '$n',
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (start == 9)
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: SizedBox(
                                      height: 52,
                                      child: TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => setState(
                                                () => _custom = true,
                                              ),
                                        child: Text(
                                          t(['更多', 'More', '更多', 'เพิ่มเติม']),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (_custom)
                        TextField(
                          controller: _more,
                          autofocus: true,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          decoration: InputDecoration(
                            labelText: t(['人数', 'Guests', '人數', 'จำนวนคน']),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(_error!),
                        ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _busy ? null : _confirm,
                          child: Text(
                            t([
                              '开始点餐',
                              'Start ordering',
                              '開始點餐',
                              'เริ่มสั่งอาหาร',
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
