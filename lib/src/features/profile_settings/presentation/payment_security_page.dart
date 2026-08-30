import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PaymentSecurityScenario {
  statusSet,
  statusNotSet,
  wrongOldPin,
  locked,
  resultUnknown,
  sessionInvalid,
}

class PaymentSecurityPage extends StatefulWidget {
  const PaymentSecurityPage({
    super.key,
    this.initialScenario = PaymentSecurityScenario.statusSet,
    this.onBack,
    this.onSessionResetRequested,
  });

  final PaymentSecurityScenario initialScenario;
  final VoidCallback? onBack;
  final VoidCallback? onSessionResetRequested;

  @override
  State<PaymentSecurityPage> createState() => _PaymentSecurityPageState();
}

enum _PinFlowStep {
  overview,
  verifyOld,
  verifySms,
  enterNew,
  confirmNew,
  success,
  resultUnknown,
}

class _PaymentSecurityPageState extends State<PaymentSecurityPage>
    with WidgetsBindingObserver {
  static const _gold = Color(0xFFC9B69E);
  static const _muted = Color(0xFF999999);

  final _controller = TextEditingController();
  _PinFlowStep _step = _PinFlowStep.overview;
  String _firstPin = '';
  String? _error;
  late PaymentSecurityScenario _scenario;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scenario = widget.initialScenario;
    if (_scenario == PaymentSecurityScenario.sessionInvalid) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSessionInvalid(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _clearSensitiveInput();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _SecurityHeader(
              title: '支付安全',
              onBack: _finishBack,
              onTitleLongPress: _showScenarioPanel,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(30, 44, 30, 32),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _buildStep(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _PinFlowStep.overview:
        return _overview();
      case _PinFlowStep.verifyOld:
        return _pinForm(
          key: 'old',
          title: '验证原支付 PIN',
          note: '请输入原 6 位支付 PIN',
          action: '下一步',
          onSubmit: () {
            if (!_validatePin()) return;
            if (_scenario == PaymentSecurityScenario.wrongOldPin) {
              _controller.clear();
              setState(() => _error = '原 PIN 错误，还可尝试 2 次');
              return;
            }
            _goTo(_PinFlowStep.enterNew);
          },
          footer: TextButton(
            onPressed: () => _goTo(_PinFlowStep.verifySms),
            child: const Text('忘记 PIN，使用短信验证'),
          ),
        );
      case _PinFlowStep.verifySms:
        return _pinForm(
          key: 'sms',
          title: '短信安全验证',
          note: '验证码已发送至绑定手机（号码不展示）',
          action: '验证',
          obscure: false,
          onSubmit: () {
            if (_controller.text != '888888') {
              setState(() => _error = '验证码不正确，请重新输入');
              return;
            }
            _goTo(_PinFlowStep.enterNew);
          },
        );
      case _PinFlowStep.enterNew:
        return _pinForm(
          key: 'new',
          title: '设置新的支付 PIN',
          note: '请输入新的 6 位数字 PIN，请勿使用 123456 或连续相同数字',
          action: '下一步',
          onSubmit: () {
            if (!_validatePin(checkSimple: true)) return;
            _firstPin = _controller.text;
            _goTo(_PinFlowStep.confirmNew);
          },
        );
      case _PinFlowStep.confirmNew:
        return _pinForm(
          key: 'confirm',
          title: '再次输入支付 PIN',
          note: '请再次输入新的 6 位数字 PIN',
          action: '确认修改',
          onSubmit: () {
            if (!_validatePin()) return;
            if (_controller.text != _firstPin) {
              setState(() => _error = '两次输入不一致，请重新输入');
              _controller.clear();
              return;
            }
            _clearSensitiveInput();
            setState(
              () => _step = _scenario == PaymentSecurityScenario.resultUnknown
                  ? _PinFlowStep.resultUnknown
                  : _PinFlowStep.success,
            );
          },
        );
      case _PinFlowStep.success:
        return Column(
          key: const ValueKey('payment-pin-success'),
          children: [
            const SizedBox(height: 70),
            const Icon(Icons.check_circle_outline, color: _gold, size: 76),
            const SizedBox(height: 26),
            const Text(
              '支付 PIN 修改成功',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text('新的支付 PIN 已生效，请妥善保管。', style: TextStyle(color: _muted)),
            const SizedBox(height: 38),
            FilledButton(onPressed: _finishBack, child: const Text('返回设置')),
          ],
        );
      case _PinFlowStep.resultUnknown:
        return Column(
          key: const ValueKey('payment-pin-result-unknown'),
          children: [
            const SizedBox(height: 70),
            const Icon(Icons.sync_problem_outlined, color: _gold, size: 76),
            const SizedBox(height: 26),
            const Text(
              '修改结果确认中',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '敏感输入已清理。请勿重复设置，系统将使用原操作标识继续查询结果。',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 38),
            FilledButton(onPressed: _finishBack, child: const Text('返回设置')),
          ],
        );
    }
  }

  Widget _overview() {
    final locked = _scenario == PaymentSecurityScenario.locked;
    final notSet = _scenario == PaymentSecurityScenario.statusNotSet;
    return Column(
      key: const ValueKey('payment-pin-overview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF171411),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x334A4035)),
          ),
          child: Row(
            children: [
              Icon(
                locked ? Icons.lock_clock_outlined : Icons.shield_outlined,
                color: locked ? const Color(0xFFE06B6B) : _gold,
                size: 38,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locked
                          ? '支付 PIN 已锁定'
                          : notSet
                          ? '支付 PIN 未设置'
                          : '支付 PIN 已设置',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      locked ? '请稍后再试，具体解锁时间以页面提示为准' : '用于余额、金币等敏感支付确认',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 34),
        FilledButton(
          key: const ValueKey('payment-pin-change'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: _gold,
            foregroundColor: const Color(0xFF241B13),
          ),
          onPressed: locked
              ? null
              : () => _goTo(
                  notSet ? _PinFlowStep.verifySms : _PinFlowStep.verifyOld,
                ),
          child: Text(
            locked
                ? '暂时无法操作'
                : notSet
                ? '设置支付 PIN'
                : '修改支付 PIN',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey('payment-pin-forgot'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: _gold,
            side: const BorderSide(color: Color(0xFF4A4035)),
          ),
          onPressed: locked ? null : () => _goTo(_PinFlowStep.verifySms),
          child: const Text('忘记 PIN，短信验证后重设'),
        ),
        const SizedBox(height: 26),
        const Text(
          '安全提示：平台工作人员不会向你索要支付 PIN。',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _pinForm({
    required String key,
    required String title,
    required String note,
    required String action,
    required VoidCallback onSubmit,
    bool obscure = true,
    Widget? footer,
  }) {
    return Column(
      key: ValueKey('payment-pin-$key'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(note, style: const TextStyle(color: _muted, height: 1.5)),
        const SizedBox(height: 34),
        TextField(
          key: ValueKey('payment-pin-input-$key'),
          controller: _controller,
          autofocus: true,
          obscureText: obscure,
          enableSuggestions: false,
          autocorrect: false,
          enableInteractiveSelection: false,
          autofillHints: const <String>[],
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: const TextStyle(
            color: Colors.black,
            fontSize: 26,
            letterSpacing: 10,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '••••••',
            errorText: _error,
            filled: true,
            fillColor: const Color(0xFF999999),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          key: ValueKey('payment-pin-submit-$key'),
          style: FilledButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: const Color(0xFF241B13),
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: onSubmit,
          child: Text(action),
        ),
        ?footer,
        const SizedBox(height: 24),
      ],
    );
  }

  bool _validatePin({bool checkSimple = false}) {
    final pin = _controller.text;
    if (pin.length != 6) {
      setState(() => _error = '请输入 6 位数字');
      return false;
    }
    if (checkSimple &&
        (RegExp(r'^(.)\1{5}$').hasMatch(pin) ||
            pin == '123456' ||
            pin == '654321')) {
      setState(() => _error = 'PIN 过于简单，请重新设置');
      return false;
    }
    return true;
  }

  void _goTo(_PinFlowStep step) {
    _controller.clear();
    setState(() {
      _error = null;
      _step = step;
    });
  }

  void _clearSensitiveInput() {
    _controller.clear();
    _firstPin = '';
    _error = null;
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
              '支付安全 UI Mock 场景',
              style: TextStyle(
                color: _gold,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (final scenario in PaymentSecurityScenario.values)
              ListTile(
                key: ValueKey('payment-scenario-${scenario.name}'),
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
                  _clearSensitiveInput();
                  setState(() {
                    _scenario = scenario;
                    _step = _PinFlowStep.overview;
                  });
                  if (scenario == PaymentSecurityScenario.sessionInvalid) {
                    _showSessionInvalid();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  String _scenarioLabel(PaymentSecurityScenario scenario) => switch (scenario) {
    PaymentSecurityScenario.statusSet => '已设置',
    PaymentSecurityScenario.statusNotSet => '未设置 · 短信重设',
    PaymentSecurityScenario.wrongOldPin => '原 PIN 错误',
    PaymentSecurityScenario.locked => '服务端锁定',
    PaymentSecurityScenario.resultUnknown => '提交结果未知',
    PaymentSecurityScenario.sessionInvalid => '会话失效',
  };

  Future<void> _showSessionInvalid() async {
    _clearSensitiveInput();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('payment-session-dialog'),
        title: const Text('登录状态已失效'),
        content: const Text('支付 PIN 输入和页面内存状态已清理，请重新登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('payment-session-confirm'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (mounted) widget.onSessionResetRequested?.call();
  }

  void _finishBack() {
    _clearSensitiveInput();
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.maybePop(context);
    }
  }
}

class _SecurityHeader extends StatelessWidget {
  const _SecurityHeader({
    required this.title,
    required this.onBack,
    required this.onTitleLongPress,
  });
  final String title;
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
              size: 22,
            ),
          ),
          Expanded(
            child: GestureDetector(
              key: const ValueKey('payment-security-title'),
              onLongPress: onTitleLongPress,
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(
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
