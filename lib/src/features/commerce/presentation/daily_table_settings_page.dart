import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../data/table_management_repository.dart';
import 'ordering_entry_status.dart';

class DailyTableSettingsPage extends StatefulWidget {
  const DailyTableSettingsPage({
    super.key,
    required this.tableId,
    required this.storeRef,
    required this.businessDate,
    required this.repository,
    required this.locale,
    required this.onBack,
  });
  final String tableId, storeRef, businessDate;
  final TableManagementRepository repository;
  final Locale locale;
  final VoidCallback onBack;
  @override
  State<DailyTableSettingsPage> createState() => _DailyTableSettingsPageState();
}

class _DailyTableSettingsPageState extends State<DailyTableSettingsPage> {
  late String _date = widget.businessDate;
  final _value = TextEditingController();
  String _mode = 'manual';
  int? _revision, _next;
  List<dynamic> _history = [];
  bool _busy = false;
  String? _error, _request, _signature;
  String t(List<String> values) =>
      OrderingEntryStatus.text(widget.locale, values);
  String label(String mode) => switch (mode) {
    'minimum_spend' => t(['最低消费台', 'Minimum spend', '最低消費台', 'โต๊ะยอดขั้นต่ำ']),
    'minimum_people' => t([
      '最少人数台',
      'Minimum guests',
      '最少人數台',
      'โต๊ะจำนวนคนขั้นต่ำ',
    ]),
    'aa' => t(['AA制桌台', 'AA table', 'AA制桌台', 'โต๊ะหารค่าใช้จ่าย']),
    _ => t(['人工开台', 'Staff opening', '人工開台', 'พนักงานเปิดโต๊ะ']),
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
      if (!more) _revision = null;
    });
    try {
      final result = await widget.repository.history(
        widget.tableId,
        widget.storeRef,
        _date,
        before: more ? _next : null,
      );
      if (!mounted) return;
      final rows = result['entries'] as List;
      setState(() {
        _history = more ? [..._history, ...rows] : rows;
        _next = result['nextBeforeRevision'] as int?;
        if (!more) {
          _revision = rows.isEmpty ? 0 : rows.first['revision'] as int;
          final rule = rows.isEmpty
              ? <String, dynamic>{'mode': 'manual'}
              : rows.first['rule'] as Map;
          _mode = rule['mode'] as String;
          _value.text = _mode == 'minimum_people'
              ? '${rule['minimumPeople']}'
              : _mode == 'minimum_spend'
              ? ((rule['minimumSpendCents'] as int) / 100).toStringAsFixed(2)
              : '';
          _request = null;
          _signature = null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = t([
            '无法读取设置，请确认权限后重试',
            'Unable to load. Check access and retry.',
            '無法讀取設定，請確認權限後重試',
            'โหลดไม่ได้ โปรดตรวจสอบสิทธิ์แล้วลองอีกครั้ง',
          ]),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_revision == null) return;
    final rule = <String, dynamic>{'mode': _mode};
    final text = _value.text.trim();
    if (_mode == 'minimum_people') {
      final number = int.tryParse(text);
      if (number == null || number < 1 || number > 65535) {
        _invalid();
        return;
      }
      rule['minimumPeople'] = number;
    } else if (_mode == 'minimum_spend') {
      if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(text)) {
        _invalid();
        return;
      }
      final parts = text.split('.');
      final cents =
          int.parse(parts.first) * 100 +
          int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
      if (cents < 1 || cents > 2147483647) {
        _invalid();
        return;
      }
      rule['minimumSpendCents'] = cents;
    }
    final signature = '$_date:$_revision:$rule';
    if (_signature != signature) {
      _signature = signature;
      _request = const Uuid().v4();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.saveRule(
        widget.tableId,
        widget.storeRef,
        _date,
        _revision!,
        _request!,
        rule,
      );
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = t([
            '未能确认保存。可重试，或刷新查看最新设置。',
            'Save not confirmed. Retry or refresh the latest settings.',
            '未能確認儲存。可重試或重新整理最新設定。',
            'ยังยืนยันการบันทึกไม่ได้ ลองอีกครั้งหรือรีเฟรช',
          ]),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _invalid() => setState(
    () => _error = t([
      '请输入有效数值',
      'Enter a valid value',
      '請輸入有效數值',
      'กรุณาระบุค่าที่ถูกต้อง',
    ]),
  );
  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _date = selected.toIso8601String().substring(0, 10);
      _history = [];
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: kingAppBar(
      context: context,
      leading: KingBackButton(onPressed: widget.onBack),
      title: Text(
        t(['每日桌台设置', 'Daily table settings', '每日桌台設定', 'ตั้งค่าโต๊ะรายวัน']),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(widget.tableId),
              TextButton(
                onPressed: _busy ? null : _pickDate,
                child: Text(_date),
              ),
              DropdownButtonFormField<String>(
                initialValue: _mode,
                key: ValueKey('$_date:$_revision:$_mode'),
                isExpanded: true,
                items: ['manual', 'minimum_spend', 'minimum_people', 'aa']
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(label(mode)),
                      ),
                    )
                    .toList(),
                onChanged: _busy || _revision == null
                    ? null
                    : (value) => setState(() {
                        _mode = value!;
                        _value.clear();
                      }),
              ),
              if (_mode == 'minimum_people' || _mode == 'minimum_spend')
                TextField(
                  controller: _value,
                  enabled: !_busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    LengthLimitingTextInputFormatter(12),
                  ],
                  decoration: InputDecoration(
                    labelText: _mode == 'minimum_people'
                        ? t([
                            '最少人数',
                            'Minimum guests',
                            '最少人數',
                            'จำนวนคนขั้นต่ำ',
                          ])
                        : t([
                            '最低消费金额',
                            'Minimum spend amount',
                            '最低消費金額',
                            'ยอดขั้นต่ำ',
                          ]),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                t([
                  '仅影响后续开台，已开台保留原规则。',
                  'Applies to future openings. Current sessions keep their rules.',
                  '僅影響後續開台，已開台保留原規則。',
                  'มีผลกับการเปิดโต๊ะครั้งถัดไป โต๊ะที่เปิดแล้วใช้กฎเดิม',
                ]),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_error!),
                ),
              if (_busy) const Center(child: CircularProgressIndicator()),
              FilledButton(
                onPressed: _busy || _revision == null ? null : _save,
                child: Text(t(['保存', 'Save', '儲存', 'บันทึก'])),
              ),
              TextButton(
                onPressed: _busy ? null : _load,
                child: Text(t(['刷新', 'Refresh', '重新整理', 'รีเฟรช'])),
              ),
              const Divider(),
              Text(
                t([
                  '当日修改历史',
                  'Changes on this date',
                  '當日修改歷史',
                  'ประวัติการเปลี่ยนแปลงวันนี้',
                ]),
              ),
              for (final row in _history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${label(row['rule']['mode'] as String)} · ${row['revision']}',
                  ),
                  subtitle: Text(
                    '${row['createdDate']}\n${row['operatedBy']}\n${row['rule']['minimumPeople'] ?? (row['rule']['minimumSpendCents'] == null ? '' : ((row['rule']['minimumSpendCents'] as int) / 100).toStringAsFixed(2))}',
                  ),
                ),
              if (_next != null)
                TextButton(
                  onPressed: _busy ? null : () => _load(more: true),
                  child: Text(t(['更多', 'More', '更多', 'เพิ่มเติม'])),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
