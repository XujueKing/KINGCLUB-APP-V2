import 'package:flutter/material.dart';

import 'about_legal_page.dart';
import 'account_deletion_page.dart';
import 'payment_security_page.dart';

enum SettingsScenario {
  normal,
  capabilityFailure,
  notificationDisabled,
  logoutUnknown,
  sessionInvalid,
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.initialScenario = SettingsScenario.normal,
    this.onBack,
    this.onOpenPaymentSecurity,
    this.onOpenAccountDeletion,
    this.onOpenAboutLegal,
    this.onLogoutCompleted,
    this.onSessionResetRequested,
  });

  final SettingsScenario initialScenario;
  final VoidCallback? onBack;
  final VoidCallback? onOpenPaymentSecurity;
  final VoidCallback? onOpenAccountDeletion;
  final VoidCallback? onOpenAboutLegal;
  final VoidCallback? onLogoutCompleted;
  final VoidCallback? onSessionResetRequested;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _gold = Color(0xFFC9B69E);
  static const _muted = Color(0xFF8B8174);
  String _cache = '12.8 MB';
  late SettingsScenario _scenario;

  static const _entries = [
    ('payment', '支付安全', '支付密码与验证', Icons.shield_outlined),
    ('notification', '通知权限', '跟随系统', Icons.notifications_none),
    ('cache', '清理缓存', '', Icons.cleaning_services_outlined),
    ('about', '关于与法律', 'KingClub V2', Icons.info_outline),
    ('deletion', '账号注销', '', Icons.no_accounts_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _scenario = widget.initialScenario;
    if (_scenario == SettingsScenario.sessionInvalid) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSessionInvalid(),
      );
    }
  }

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
                    onPressed: _finishBack,
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: _gold,
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      key: const ValueKey('settings-title'),
                      onLongPress: _showScenarioPanel,
                      child: const Center(
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
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
                children: [
                  if (_scenario == SettingsScenario.capabilityFailure) ...[
                    const _SettingsNotice(
                      key: ValueKey('settings-capability-failure'),
                      icon: Icons.cloud_off_outlined,
                      text: '部分能力状态暂时无法读取，固定安全入口仍可使用。',
                    ),
                    const SizedBox(height: 14),
                  ],
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingRow((String, String, String, IconData) entry) {
    final info = entry.$1 == 'cache'
        ? _cache
        : entry.$1 == 'notification' &&
              _scenario == SettingsScenario.notificationDisabled
        ? '已关闭'
        : entry.$3;
    return InkWell(
      key: ValueKey('settings-${entry.$1}'),
      borderRadius: BorderRadius.circular(28),
      onTap: entry.$1 == 'cache' ? _clearCache : () => _openChild(entry.$2),
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
            const SizedBox(width: 14),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: info.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        info,
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              key: ValueKey('settings-arrow-${entry.$1}'),
              width: 24,
              child: const Center(
                child: Icon(Icons.chevron_right, color: _muted, size: 21),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChild(String title) {
    if (title == '通知权限') {
      _showNotificationStatus();
      return;
    }
    if (title == '支付安全' && widget.onOpenPaymentSecurity != null) {
      widget.onOpenPaymentSecurity!();
      return;
    }
    if (title == '账号注销' && widget.onOpenAccountDeletion != null) {
      widget.onOpenAccountDeletion!();
      return;
    }
    if (title == '关于与法律' && widget.onOpenAboutLegal != null) {
      widget.onOpenAboutLegal!();
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _scenario == SettingsScenario.notificationDisabled
                  ? '系统通知已关闭'
                  : '系统通知已允许',
            ),
            const SizedBox(height: 10),
            const Text('消息通知、活动提醒和订单状态最终由手机系统设置控制。'),
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('请前往手机系统设置管理通知权限')));
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
        content: Text('将清理 $_cache 本地缓存，不影响账号资料。'),
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
          .showSnackBar(const SnackBar(content: Text('缓存已清理')));
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认注销登录？'),
        content: const Text('退出后需要重新验证手机号才能登录。'),
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
      if (_scenario == SettingsScenario.logoutUnknown) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const ValueKey('settings-logout-unknown-dialog'),
            title: const Text('远端结果暂未确认'),
            content: const Text('本机凭据和敏感内存已安全清理。下次登录时将重新校验远端会话。'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已退出登录')));
      }
      if (mounted) widget.onLogoutCompleted?.call();
    }
  }

  Future<void> _showScenarioPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171411),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          children: [
            const Text(
              '设置 UI Mock 场景',
              style: TextStyle(
                color: _gold,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text('长按标题可再次切换。', style: TextStyle(color: _muted)),
            const SizedBox(height: 10),
            for (final scenario in SettingsScenario.values)
              ListTile(
                key: ValueKey('settings-scenario-${scenario.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _scenarioLabel(scenario),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: scenario == _scenario
                    ? const Icon(Icons.check, color: _gold)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _scenario = scenario);
                  if (scenario == SettingsScenario.sessionInvalid) {
                    _showSessionInvalid();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  String _scenarioLabel(SettingsScenario scenario) => switch (scenario) {
    SettingsScenario.normal => '正常设置',
    SettingsScenario.capabilityFailure => '能力加载失败',
    SettingsScenario.notificationDisabled => '通知已关闭',
    SettingsScenario.logoutUnknown => '退出远端结果未知',
    SettingsScenario.sessionInvalid => '会话失效',
  };

  Future<void> _showSessionInvalid() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('settings-session-dialog'),
        title: const Text('登录状态已失效'),
        content: const Text('设置页内的临时状态已清理，请重新登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('settings-session-confirm'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    widget.onSessionResetRequested?.call();
  }

  void _finishBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.maybePop(context);
    }
  }
}

class _SettingsNotice extends StatelessWidget {
  const _SettingsNotice({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171411),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A3026)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _SettingsPageState._gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFB8ADA0), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
