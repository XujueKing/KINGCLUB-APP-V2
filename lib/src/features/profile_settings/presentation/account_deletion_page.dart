import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AccountDeletionScenario {
  eligible,
  openOrderBlocker,
  assetStorageBlocker,
  smsExpired,
  resultUnknown,
  stateChanged,
  sessionInvalid,
}

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({
    super.key,
    this.initialScenario = AccountDeletionScenario.eligible,
    this.onBack,
    this.onCompleted,
    this.onSessionResetRequested,
  });

  final AccountDeletionScenario initialScenario;
  final VoidCallback? onBack;
  final VoidCallback? onCompleted;
  final VoidCallback? onSessionResetRequested;

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  static const _gold = Color(0xFFC9B69E);
  static const _muted = Color(0xFF9E9589);
  bool _acknowledged = false;
  bool _completed = false;
  bool _resultUnknown = false;
  late AccountDeletionScenario _scenario;

  bool get _blocked =>
      _scenario == AccountDeletionScenario.openOrderBlocker ||
      _scenario == AccountDeletionScenario.assetStorageBlocker ||
      _scenario == AccountDeletionScenario.stateChanged;

  @override
  void initState() {
    super.initState();
    _scenario = widget.initialScenario;
    if (_scenario == AccountDeletionScenario.sessionInvalid) {
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
            _DeletionHeader(
              onBack: _finishBack,
              onTitleLongPress: _showScenarioPanel,
            ),
            Expanded(
              child: _completed
                  ? _completedView()
                  : _resultUnknown
                  ? _resultUnknownView()
                  : _content(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final checks = <(String, String, bool, String?)>[
      (
        '无未结订单',
        _scenario == AccountDeletionScenario.openOrderBlocker
            ? '有 1 笔待处理'
            : '已通过',
        _scenario == AccountDeletionScenario.openOrderBlocker,
        '去处理订单',
      ),
      (
        '余额、退款与优惠权益',
        _scenario == AccountDeletionScenario.assetStorageBlocker
            ? '有余额或退款待处理'
            : '已处理',
        _scenario == AccountDeletionScenario.assetStorageBlocker,
        '去处理资产',
      ),
      (
        '私人储物柜物品',
        _scenario == AccountDeletionScenario.assetStorageBlocker
            ? '有 1 件待取物品'
            : '无待取物品',
        _scenario == AccountDeletionScenario.assetStorageBlocker,
        '去处理储物',
      ),
      ('申诉与纠纷', '无处理中事项', false, null),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFC9B69E),
          size: 68,
        ),
        const SizedBox(height: 18),
        const Text(
          '永久注销 KingClub',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '仅注销 KingClub 会员与业务资料；物业账号、物业数据及共享身份不受影响。',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.6),
        ),
        const SizedBox(height: 30),
        if (_scenario == AccountDeletionScenario.stateChanged) ...[
          const _DeletionNotice(
            key: ValueKey('account-deletion-state-changed'),
            text: '注销资格已变化，请重新检查订单、资产和储物状态后再继续。',
          ),
          const SizedBox(height: 20),
        ],
        _section('注销后将放弃以下权益与数据', const [
          '无法继续登录 KingClub 或恢复历史会员资料',
          '无法查询历史订单、聊天和活动记录',
          '余额、金币、礼品券及优惠权益不可恢复',
          '依法必须留存的交易与安全记录将在期限内保留',
        ]),
        const SizedBox(height: 24),
        const Text(
          '注销资格检查',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...checks.map(
          (item) => Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x22C9B69E))),
            ),
            child: Row(
              children: [
                Icon(
                  item.$3 ? Icons.error_outline : Icons.check_circle_outline,
                  color: item.$3
                      ? const Color(0xFFE06B6B)
                      : const Color(0xFF8DA783),
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.$1, style: const TextStyle(color: _gold)),
                ),
                if (item.$3)
                  TextButton(
                    key: ValueKey('account-deletion-blocker-${item.$4}'),
                    onPressed: () => _showBlockerIntent(item.$4!),
                    child: Text(item.$4!),
                  )
                else
                  Text(
                    item.$2,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        CheckboxListTile(
          key: const ValueKey('account-deletion-ack'),
          value: _acknowledged,
          activeColor: _gold,
          checkColor: Colors.black,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: _blocked
              ? null
              : (value) => setState(() => _acknowledged = value ?? false),
          title: const Text(
            '我已阅读并知悉注销影响与数据处理说明',
            style: TextStyle(color: _gold, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('account-deletion-start'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: const Color(0xFF7F2626),
            disabledBackgroundColor: const Color(0xFF392323),
          ),
          onPressed: _acknowledged && !_blocked ? _verifySms : null,
          child: const Text('完成短信验证并永久注销'),
        ),
        const SizedBox(height: 12),
        const Text(
          'UI Mock：不会注销真实账号或清理真实会话。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF554D44), fontSize: 11),
        ),
      ],
    );
  }

  Widget _section(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF15120F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _gold,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(
                '• $item',
                style: const TextStyle(
                  color: _muted,
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifySms() async {
    final controller = TextEditingController();
    String? error;
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('短信安全验证'),
          content: TextField(
            key: const ValueKey('account-deletion-sms-input'),
            controller: controller,
            autofocus: true,
            enableInteractiveSelection: false,
            autofillHints: const <String>[],
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: '验证码',
              helperText: 'UI 测试验证码：888888',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (_scenario == AccountDeletionScenario.smsExpired) {
                  setDialogState(() => error = '验证码已过期，请重新获取');
                  return;
                }
                if (controller.text != '888888') {
                  setDialogState(() => error = '验证码不正确');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('验证'),
            ),
          ],
        ),
      ),
    );
    if (verified == true && mounted) _finalConfirm();
  }

  Future<void> _finalConfirm() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('最后确认'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('此操作不可恢复。请输入“永久注销”继续。'),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('account-deletion-confirm-input'),
              controller: controller,
              enableSuggestions: false,
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8C2929),
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim() == '永久注销'),
            child: const Text('确认永久注销'),
          ),
        ],
      ),
    );
    controller.clear();
    if (confirmed == true && mounted) {
      setState(() {
        if (_scenario == AccountDeletionScenario.resultUnknown) {
          _resultUnknown = true;
        } else {
          _completed = true;
        }
      });
    }
  }

  Widget _completedView() {
    return Center(
      key: const ValueKey('account-deletion-completed'),
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: _gold, size: 76),
            const SizedBox(height: 22),
            const Text(
              'Fake 注销流程已完成',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '真实 KingClub 与物业账号均未发生变化。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 28),
            FilledButton(
              key: const ValueKey('account-deletion-completed-exit'),
              onPressed: () {
                widget.onCompleted?.call();
                _finishBack();
              },
              child: const Text('返回设置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultUnknownView() {
    return Center(
      key: const ValueKey('account-deletion-result-unknown'),
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_problem_outlined, color: _gold, size: 76),
            const SizedBox(height: 22),
            const Text(
              '注销结果确认中',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '请勿重复提交。系统将使用原操作标识继续查询，确认前不会声称注销成功。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 28),
            FilledButton(onPressed: _finishBack, child: const Text('返回设置')),
          ],
        ),
      ),
    );
  }

  void _showBlockerIntent(String action) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('UI Mock：$action，仅传受控业务引用')));
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
              '账号注销 UI Mock 场景',
              style: TextStyle(
                color: _gold,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (final scenario in AccountDeletionScenario.values)
              ListTile(
                key: ValueKey('deletion-scenario-${scenario.name}'),
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
                  setState(() {
                    _scenario = scenario;
                    _acknowledged = false;
                    _completed = false;
                    _resultUnknown = false;
                  });
                  if (scenario == AccountDeletionScenario.sessionInvalid) {
                    _showSessionInvalid();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  String _scenarioLabel(AccountDeletionScenario scenario) => switch (scenario) {
    AccountDeletionScenario.eligible => '符合注销资格',
    AccountDeletionScenario.openOrderBlocker => '未结订单阻断',
    AccountDeletionScenario.assetStorageBlocker => '资产 / 储物阻断',
    AccountDeletionScenario.smsExpired => '短信验证码过期',
    AccountDeletionScenario.resultUnknown => '提交结果未知',
    AccountDeletionScenario.stateChanged => '资格状态已变化',
    AccountDeletionScenario.sessionInvalid => '会话失效',
  };

  Future<void> _showSessionInvalid() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('deletion-session-dialog'),
        title: const Text('登录状态已失效'),
        content: const Text('注销验证码、确认文本和页面内存状态已清理，请重新登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('deletion-session-confirm'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (mounted) widget.onSessionResetRequested?.call();
  }

  void _finishBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.maybePop(context);
    }
  }
}

class _DeletionHeader extends StatelessWidget {
  const _DeletionHeader({required this.onBack, required this.onTitleLongPress});
  final VoidCallback onBack;
  final VoidCallback onTitleLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFFC9B69E),
              size: 21,
            ),
          ),
          Expanded(
            child: GestureDetector(
              key: const ValueKey('account-deletion-title'),
              onLongPress: onTitleLongPress,
              child: const Center(
                child: Text(
                  '账号注销',
                  style: TextStyle(
                    color: Color(0xFFC9B69E),
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
    );
  }
}

class _DeletionNotice extends StatelessWidget {
  const _DeletionNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF211616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF623535)),
      ),
      child: Row(
        children: [
          const Icon(Icons.refresh, color: Color(0xFFE06B6B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFD6C7BC), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
