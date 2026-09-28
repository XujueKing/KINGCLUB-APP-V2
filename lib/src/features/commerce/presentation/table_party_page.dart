import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/table_management_repository.dart';
import 'ordering_entry_status.dart';

class TablePartyPage extends StatefulWidget {
  const TablePartyPage({
    super.key,
    required this.tableName,
    required this.locale,
    required this.read,
    required this.save,
    required this.onReady,
    required this.onBack,
  });
  final String tableName;
  final Locale locale;
  final Future<TableParty> Function() read;
  final Future<TableParty> Function(int count, int revision, String requestId)
  save;
  final VoidCallback onReady, onBack;
  @override
  State<TablePartyPage> createState() => _TablePartyPageState();
}

class _TablePartyPageState extends State<TablePartyPage> {
  final _count = TextEditingController(text: '1');
  TableParty? _party;
  bool _busy = false;
  String? _error;
  String? _requestId;
  int? _submittedCount;
  String t(List<String> values) =>
      OrderingEntryStatus.text(widget.locale, values);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _party = null;
    });
    try {
      final party = await widget.read();
      if (!mounted) return;
      if (party.count != null || !party.canEdit) {
        widget.onReady();
        return;
      }
      setState(() {
        _party = party;
        _requestId = null;
        _submittedCount = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = t([
            '读取失败，请重试',
            'Unable to load. Retry.',
            '讀取失敗，請重試',
            'โหลดไม่สำเร็จ กรุณาลองอีกครั้ง',
          ]),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final count = int.tryParse(_count.text);
    if (_party == null || count == null || count < 1 || count > 65535) {
      setState(
        () => _error = t([
          '请输入有效人数',
          'Enter a valid guest count',
          '請輸入有效人數',
          'กรุณาระบุจำนวนคนให้ถูกต้อง',
        ]),
      );
      return;
    }
    if (_submittedCount != count) {
      _requestId = const Uuid().v4();
      _submittedCount = count;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save(count, _party!.revision, _requestId!);
      if (mounted) widget.onReady();
    } catch (error) {
      if (!mounted) return;
      if (error is AuthFailure &&
          [
            'PARTY_REVISION_CHANGED',
            'PARTY_EDIT_NOT_ALLOWED',
          ].contains(error.code)) {
        await _load();
      } else {
        setState(
          () => _error = t([
            '未能确认保存，请重试',
            'Could not confirm saving. Retry.',
            '未能確認儲存，請重試',
            'ยืนยันการบันทึกไม่สำเร็จ กรุณาลองอีกครั้ง',
          ]),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: kingAppBar(
      context: context,
      leading: KingBackButton(onPressed: widget.onBack),
      title: Text(t(['选择人数', 'Number of guests', '選擇人數', 'จำนวนผู้ใช้บริการ'])),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.tableName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                t([
                  '几位一起？我们按人数准备杯子。',
                  'How many guests? We will prepare one cup per guest.',
                  '幾位一起？我們按人數準備杯子。',
                  'มากี่ท่าน? เราจะเตรียมแก้วตามจำนวนคน',
                ]),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _count,
                enabled: !_busy && _party != null,
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(_error!),
                ),
              const SizedBox(height: 24),
              if (_busy)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton(
                  onPressed: _party == null ? _load : _save,
                  child: Text(
                    _party == null
                        ? t(['重试', 'Retry', '重試', 'ลองอีกครั้ง'])
                        : t([
                            '确认并点单',
                            'Continue to menu',
                            '確認並點單',
                            'ยืนยันและสั่งอาหาร',
                          ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
