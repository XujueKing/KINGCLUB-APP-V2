import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../data/table_management_repository.dart';
import 'daily_table_settings_page.dart';
import 'ordering_entry_status.dart';

class ManagedTablesPage extends StatefulWidget {
  const ManagedTablesPage({
    super.key,
    required this.repository,
    required this.locale,
  });
  final TableManagementRepository repository;
  final Locale locale;
  @override
  State<ManagedTablesPage> createState() => _ManagedTablesPageState();
}

class _ManagedTablesPageState extends State<ManagedTablesPage> {
  List<dynamic> _rows = [];
  String? _next, _error;
  bool _busy = false;
  String t(List<String> values) =>
      OrderingEntryStatus.text(widget.locale, values);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.managedTables(
        after: more ? _next : null,
      );
      if (!mounted) return;
      setState(() {
        _rows = more
            ? [..._rows, ...result['tables'] as List]
            : result['tables'] as List;
        _next = result['nextAfterTable'] as String?;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = t([
            '暂时无法读取门店，请重试',
            'Unable to load stores. Retry.',
            '暫時無法讀取門店，請重試',
            'โหลดร้านไม่ได้ กรุณาลองอีกครั้ง',
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
      leading: KingBackButton(onPressed: () => Navigator.maybePop(context)),
      title: Text(
        t(['门店桌台设置', 'Store tables', '門店桌台設定', 'ตั้งค่าโต๊ะของร้าน']),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_busy) const Center(child: CircularProgressIndicator()),
        if (_error != null) Text(_error!),
        if (!_busy && _error == null && _rows.isEmpty)
          Text(
            t([
              '当前账号没有关联门店',
              'No stores linked to this account',
              '目前帳號沒有關聯門店',
              'บัญชีนี้ยังไม่มีร้านที่เชื่อมโยง',
            ]),
          ),
        for (final row in _rows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${row['storeName']} · ${row['tableName']}'),
            subtitle: Text(
              '${row['cityName']} · ${row['businessDate']}\n${row['tableStatus'] == 'active' ? t(['可用', 'Active', '可用', 'ใช้งาน']) : t(['停用，可先配置', 'Disabled; configuration available', '停用，可先設定', 'ปิดใช้งาน แต่ตั้งค่าได้'])}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => DailyTableSettingsPage(
                        tableId: row['tableId'] as String,
                        storeRef: row['storeRef'] as String,
                        businessDate: row['businessDate'] as String,
                        repository: widget.repository,
                        locale: widget.locale,
                        onBack: () => Navigator.pop(context),
                      ),
                    ),
                  ),
          ),
        if (_next != null)
          TextButton(
            onPressed: _busy ? null : () => _load(more: true),
            child: Text(t(['更多', 'More', '更多', 'เพิ่มเติม'])),
          ),
        TextButton(
          onPressed: _busy ? null : _load,
          child: Text(t(['刷新', 'Refresh', '重新整理', 'รีเฟรช'])),
        ),
      ],
    ),
  );
}
