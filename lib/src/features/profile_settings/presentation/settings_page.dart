import 'package:flutter/material.dart';

import 'about_legal_page.dart';
import 'account_deletion_page.dart';
import 'payment_security_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _gold = Color(0xFFC9B69E);
  static const _muted = Color(0xFF8B8174);
  String _cache = '12.8 MB';

  static const _entries = [
    ('payment', '支付安全', '支付密码与验证', Icons.shield_outlined),
    ('notification', '通知权限', '跟随系统', Icons.notifications_none),
    ('cache', '清理缓存', '', Icons.cleaning_services_outlined),
    ('about', '关于与法律', 'KingClub V2', Icons.info_outline),
    ('deletion', '账号注销', '', Icons.no_accounts_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('settings-back'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: _gold,
                      size: 21,
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        '设置',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
                children: [
                  ..._entries.map((entry) => _settingRow(entry)),
                  const SizedBox(height: 50),
                  OutlinedButton(
                    key: const ValueKey('settings-logout'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: _gold,
                      side: const BorderSide(color: Color(0xFF4A4035)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _confirmLogout,
                    child: const Text('注销登录'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '当前为离线 UI Mock，不会修改真实账号或系统设置。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF554D44), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingRow((String, String, String, IconData) entry) {
    final info = entry.$1 == 'cache' ? _cache : entry.$3;
    return InkWell(
      key: ValueKey('settings-${entry.$1}'),
      borderRadius: BorderRadius.circular(28),
      onTap: entry.$1 == 'cache' ? _clearCache : () => _openFakeChild(entry.$2),
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x22C9B69E))),
        ),
        child: Row(
          children: [
            Icon(entry.$4, color: _gold, size: 22),
            const SizedBox(width: 15),
            Text(entry.$2, style: const TextStyle(color: _gold, fontSize: 16)),
            const Spacer(),
            if (info.isNotEmpty)
              Flexible(
                child: Text(
                  info,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: _muted, size: 21),
          ],
        ),
      ),
    );
  }

  void _openFakeChild(String title) {
    if (title == '通知权限') {
      _showNotificationStatus();
      return;
    }
    final Widget page = switch (title) {
      '支付安全' => const PaymentSecurityPage(),
      '账号注销' => const AccountDeletionPage(),
      '关于与法律' => const AboutLegalPage(),
      _ => const SizedBox.shrink(),
    };
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _showNotificationStatus() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('通知权限'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('系统通知：已允许（Fake）'),
            SizedBox(height: 10),
            Text('消息通知、活动提醒和订单状态最终由手机系统设置控制。'),
            SizedBox(height: 10),
            Text('当前不会读取或修改真实系统权限。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('UI Mock：未打开真实系统设置')),
              );
            },
            child: const Text('打开系统设置'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理缓存'),
        content: Text('将清理 $_cache 本地 Fake 缓存，不影响账号资料。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认清理'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _cache = '0 B');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Fake 缓存已清理')));
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认注销登录？'),
        content: const Text('UI Mock 不会清除真实登录信息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('注销登录'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已完成 Fake 注销流程')));
    }
  }
}
