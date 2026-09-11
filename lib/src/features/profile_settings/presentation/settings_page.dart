import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import 'about_legal_page.dart';
import 'payment_security_page.dart';
import 'personal_info_page.dart';

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
    this.onOpenPersonalInfo,
    this.onOpenPaymentSecurity,
    this.onOpenPrivacyPolicy,
    this.onOpenUserAgreement,
    this.onOpenAccountDeletion,
    this.onOpenAboutLegal,
    this.onLogoutCompleted,
    this.onSessionResetRequested,
  });

  final SettingsScenario initialScenario;
  final VoidCallback? onBack;
  final VoidCallback? onOpenPersonalInfo;
  final VoidCallback? onOpenPaymentSecurity;
  final VoidCallback? onOpenPrivacyPolicy;
  final VoidCallback? onOpenUserAgreement;

  // Retained for the existing shell contract. Account deletion remains an
  // approved child flow even though it is no longer a top-level settings row.
  final VoidCallback? onOpenAccountDeletion;
  final VoidCallback? onOpenAboutLegal;
  final VoidCallback? onLogoutCompleted;
  final VoidCallback? onSessionResetRequested;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _gold = Color(0xFFC9B69E);
  static const _assetRoot = 'assets/legacy/profile';

  static const _entries = [
    (id: 'personal-info', label: '个人信息', asset: 'menu_my.png'),
    (id: 'account-security', label: '账号安全', asset: 'secure.png'),
    (id: 'privacy-policy', label: '隐私政策', asset: 'yinsi.png'),
    (id: 'user-agreement', label: '用户协议', asset: 'agreement.png'),
    (id: 'about-kingbar', label: '关于KINGBAR', asset: 'menu_about.png'),
  ];

  late SettingsScenario _scenario;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth = math.min(
              constraints.maxWidth,
              MediaQuery.sizeOf(context).width,
            );
            final scale = viewportWidth / 750;
            final contentWidth = math.min(690 * scale, viewportWidth - 20);

            return Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: KingBackButton.leftOffset(context),
                        top: KingBackButton.safeAreaOffset.dy,
                        child: KingBackButton(
                          key: const ValueKey('settings-back'),
                          onPressed: _finishBack,
                        ),
                      ),
                      GestureDetector(
                        key: const ValueKey('settings-title'),
                        onLongPress: _showScenarioPanel,
                        child: const Text(
                          '设置',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 19,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('settings-scroll'),
                    padding: EdgeInsets.only(
                      top: 60 * scale,
                      bottom: 140 * scale,
                    ),
                    child: Column(
                      children: [
                        if (_scenario ==
                            SettingsScenario.capabilityFailure) ...[
                          const Center(
                            child: Text(
                              '部分安全状态暂时无法读取',
                              key: ValueKey('settings-capability-failure'),
                              style: TextStyle(
                                color: Color(0x998B8174),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          SizedBox(height: 22 * scale),
                        ],
                        Center(
                          child: SizedBox(
                            width: contentWidth,
                            child: Column(
                              children: [
                                for (final entry in _entries)
                                  _settingRow(entry, scale),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20 * scale),
                        Center(
                          child: SizedBox(
                            width: math.min(600 * scale, viewportWidth - 40),
                            height: math.max(44, 90 * scale),
                            child: FilledButton(
                              key: const ValueKey('settings-logout'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF24180A),
                                foregroundColor: _gold,
                                shape: const StadiumBorder(),
                                textStyle: TextStyle(
                                  fontSize: 30 * scale,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onPressed: _confirmLogout,
                              child: const Text('注销登录'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _settingRow(
    ({String id, String label, String asset}) entry,
    double scale,
  ) {
    return Semantics(
      button: true,
      label: entry.label,
      child: InkWell(
        key: ValueKey('settings-${entry.id}'),
        onTap: () => _openEntry(entry.id),
        borderRadius: BorderRadius.circular(50 * scale),
        splashColor: _gold.withValues(alpha: .08),
        highlightColor: _gold.withValues(alpha: .05),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 30 * scale,
              vertical: 30 * scale,
            ),
            child: Row(
              children: [
                Image.asset(
                  '$_assetRoot/${entry.asset}',
                  width: 36 * scale,
                  height: 36 * scale,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                SizedBox(width: 20 * scale),
                Expanded(
                  child: Text(
                    entry.label,
                    style: TextStyle(
                      color: _gold,
                      fontSize: 31 * scale,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                SizedBox(
                  key: ValueKey('settings-arrow-${entry.id}'),
                  width: 24,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Image.asset(
                      '$_assetRoot/next.png',
                      width: 12 * scale,
                      height: 19 * scale,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openEntry(String id) {
    switch (id) {
      case 'personal-info':
        if (widget.onOpenPersonalInfo != null) {
          widget.onOpenPersonalInfo!();
          return;
        }
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const PersonalInfoPage()),
        );
        return;
      case 'account-security':
        if (widget.onOpenPaymentSecurity != null) {
          widget.onOpenPaymentSecurity!();
          return;
        }
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const PaymentSecurityPage()),
        );
        return;
      case 'privacy-policy':
        if (widget.onOpenPrivacyPolicy != null) {
          widget.onOpenPrivacyPolicy!();
          return;
        }
        _showLegalDocument(1);
        return;
      case 'user-agreement':
        if (widget.onOpenUserAgreement != null) {
          widget.onOpenUserAgreement!();
          return;
        }
        _showLegalDocument(0);
        return;
      case 'about-kingbar':
        if (widget.onOpenAboutLegal != null) {
          widget.onOpenAboutLegal!();
          return;
        }
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const AboutLegalPage()),
        );
        return;
    }
  }

  void _showLegalDocument(int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AboutLegalPage(initialDocumentIndex: index),
      ),
    );
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
              '设置 UI 场景',
              style: TextStyle(
                color: _gold,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
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
    SettingsScenario.capabilityFailure => '安全状态加载失败',
    SettingsScenario.notificationDisabled => '通知已关闭（历史场景）',
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
