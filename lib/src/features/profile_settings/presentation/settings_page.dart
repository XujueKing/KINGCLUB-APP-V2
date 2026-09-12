import '../../../core/session/secure_session_store.dart';
import '../../auth/presentation/terms_consent_page.dart';
import '../data/profile_repository.dart';
import 'edit_profile_page.dart';

import 'package:flutter/material.dart';

import '../../../core/media/media_cache.dart';

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
    this.mediaCache,
  });

  final SettingsScenario initialScenario;
  final MediaCache? mediaCache;
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
  String _cache = '计算中';
  late SettingsScenario _scenario;

  static const _entries = [
    ('profile', '个人信息', '', Icons.account_circle_outlined),
    ('security', '账号与支付安全', '', Icons.verified_user_outlined),
    ('notification', '通知权限', '', Icons.notifications_none),
    ('cache', '清理缓存', '', Icons.cleaning_services_outlined),
    ('privacy', '隐私政策', '', Icons.policy_outlined),
    ('terms', '用户协议', '', Icons.description_outlined),
    ('about', '关于 KINGCLUB', '', Icons.touch_app_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _scenario = widget.initialScenario;
    _readCache();
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('settings-back'),
                      onPressed: _finishBack,
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: _gold,
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        key: const ValueKey('settings-title'),
                        onLongPress: _showScenarioPanel,
                        child: const Center(
                          child: Text(
                            '设置',
                            style: TextStyle(color: _gold, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 20),
                children: [
                  if (_scenario == SettingsScenario.capabilityFailure)
                    const _SettingsNotice(
                      key: ValueKey('settings-capability-failure'),
                      icon: Icons.cloud_off_outlined,
                      text: '部分能力状态暂时无法读取，固定安全入口仍可使用。',
                    ),
                  ..._entries.map(_settingRow),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 16, 36, 48),
              child: FilledButton(
                key: const ValueKey('settings-logout'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF291C0B),
                  foregroundColor: _gold,
                  minimumSize: const Size.fromHeight(46),
                  shape: const StadiumBorder(),
                ),
                onPressed: _confirmLogout,
                child: const Text(
                  '注销登录',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
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
        constraints: const BoxConstraints(minHeight: 53),
        padding: const EdgeInsets.symmetric(horizontal: 0),
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
                child: Icon(Icons.chevron_right, color: _gold, size: 21),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChild(String title) {
    if (title == '绑定手机' || title == '登录密码' || title == '账号关联') {
      final message = switch (title) {
        '绑定手机' => '绑定手机是当前账号的短信登录号码，暂不支持修改。',
        '登录密码' => '当前使用手机短信验证码登录，登录密码功能暂未开放。',
        _ => '第三方账号绑定与解绑功能暂未开放。',
      };
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    if (title == '个人信息') {
      _openProfile();
      return;
    }
    if (title == '账号与支付安全') {
      _push(
        Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(title: const Text('安全中心'), centerTitle: true),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                FutureBuilder<Map<String, dynamic>?>(
                  future: SecureSessionStore().readSession(),
                  builder: (_, snapshot) => _settingRow((
                    'phone',
                    '绑定手机',
                    snapshot.data?['maskedMobile'] as String? ?? '已绑定',
                    Icons.sim_card_outlined,
                  )),
                ),
                _settingRow(('password', '登录密码', '暂未开放', Icons.lock_outline)),
                _settingRow(('linked', '账号关联', '暂未开放', Icons.link_outlined)),
                _settingRow(('payment', '支付安全', '', Icons.shield_outlined)),
                _settingRow((
                  'deletion',
                  '永久注销账号',
                  '注销后无法恢复',
                  Icons.no_accounts_outlined,
                )),
              ],
            ),
          ),
        ),
      );
      return;
    }
    if (title == '隐私政策' || title == '用户协议') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          allowSnapshotting: false,
          builder: (pageContext) => TermsConsentPage(
            initialAgreement: title == '隐私政策'
                ? AgreementKind.privacy
                : AgreementKind.terms,
            onClose: () => Navigator.of(pageContext).pop(),
          ),
        ),
      );
      return;
    }
    if (title == '通知权限') {
      _showNotificationStatus();
      return;
    }
    if (title == '支付安全' && widget.onOpenPaymentSecurity != null) {
      widget.onOpenPaymentSecurity!();
      return;
    }
    if (title == '永久注销账号' && widget.onOpenAccountDeletion != null) {
      widget.onOpenAccountDeletion!();
      return;
    }
    if (title == '关于 KINGCLUB' && widget.onOpenAboutLegal != null) {
      widget.onOpenAboutLegal!();
      return;
    }
    final Widget page = switch (title) {
      '支付安全' => const PaymentSecurityPage(),
      '永久注销账号' => const AccountDeletionPage(),
      '关于 KINGCLUB' => const AboutLegalPage(),
      _ => const SizedBox.shrink(),
    };
    Navigator.push(
      context,
      MaterialPageRoute<void>(allowSnapshotting: false, builder: (_) => page),
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(allowSnapshotting: false, builder: (_) => page),
    );
  }

  bool _loadingProfile = false;
  Future<void> _openProfile() async {
    if (_loadingProfile) return;
    _loadingProfile = true;
    try {
      final repository = ProfileRepository();
      final profile = await repository.load();
      if (!mounted) return;
      _push(
        EditProfilePage(
          nickname: profile['nickname'] as String? ?? '',
          signature: profile['bio'] as String? ?? '',
          realProfile: profile,
          repository: repository,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('个人信息暂时无法加载，请重试')));
      }
    } finally {
      _loadingProfile = false;
    }
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
      try {
        await (widget.mediaCache ?? MediaCache.shared).clear();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('缓存清理失败，请重试')));
        }
        return;
      }
      if (!mounted) return;
      setState(() => _cache = '0 B');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('缓存已清理')));
    }
  }

  Future<void> _readCache() async {
    try {
      final bytes = await (widget.mediaCache ?? MediaCache.shared).sizeBytes();
      if (mounted) {
        setState(
          () => _cache = bytes == 0
              ? '0 B'
              : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _cache = '暂不可用');
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
