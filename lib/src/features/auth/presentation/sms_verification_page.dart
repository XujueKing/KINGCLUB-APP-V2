import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_theme.dart';
import '../../../core/mock/mock_runtime.dart';

class SmsVerificationPage extends ConsumerStatefulWidget {
  const SmsVerificationPage({
    super.key,
    required this.flowId,
    required this.onBack,
    required this.onVerified,
  });

  final String flowId;
  final VoidCallback onBack;
  final ValueChanged<String> onVerified;

  @override
  ConsumerState<SmsVerificationPage> createState() =>
      _SmsVerificationPageState();
}

class _SmsVerificationPageState extends ConsumerState<SmsVerificationPage> {
  final _codeController = TextEditingController();
  Timer? _timer;
  int _remaining = 60;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _remaining == 0) return;
      setState(() => _remaining--);
    });
  }

  Future<void> _handleSecondaryAction() async {
    if (_remaining == 0) {
      setState(() => _remaining = 60);
      _startCountdown();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('验证码已重新发送')));
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('收不到验证码？'),
        content: const Text('请确认手机号填写正确、短信未被拦截，并在倒计时结束后重新获取。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_submitting || _codeController.text.length != 6) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final outcome = await ref
        .read(mockRuntimeProvider)
        .verifyCode(flowId: widget.flowId, code: _codeController.text);
    if (!mounted) return;
    switch (outcome) {
      case CodeVerificationOutcome.verified:
        final onboardingId = ref.read(mockRuntimeProvider).startOnboarding();
        widget.onVerified(onboardingId);
      case CodeVerificationOutcome.invalid:
        _codeController.clear();
        setState(() {
          _submitting = false;
          _error = '验证码不正确，请重新输入';
        });
      case CodeVerificationOutcome.expired:
        _codeController.clear();
        setState(() {
          _submitting = false;
          _error = '验证码已过期，请重新获取';
        });
      case CodeVerificationOutcome.outcomeUnknown:
        _codeController.clear();
        ref.read(mockRuntimeProvider).clearFlow(widget.flowId);
        setState(() {
          _submitting = false;
          _error = '验证结果暂时无法确认，请返回重新获取验证码';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.read(mockRuntimeProvider).flow(widget.flowId);
    if (flow == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onBack());
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back, size: 22),
        ),
        title: const Text('验证手机号'),
      ),
      body: KingPageBody(
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('输入验证码', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              '验证码已发送至 ${flow?.maskedMobile ?? '当前手机号'}',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: KingColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Semantics(
              label: '六位验证码',
              textField: true,
              child: SizedBox(
                height: 62,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Row(
                        children: List.generate(6, (index) {
                          final code = _codeController.text;
                          final value = index < code.length ? code[index] : '';
                          final active =
                              index == code.length && code.length < 6;
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: index == 5 ? 0 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: KingColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _error != null
                                      ? KingColors.danger
                                      : active
                                      ? KingColors.brand
                                      : KingColors.border,
                                  width: active ? 1.5 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                value,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: KingColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.01,
                        child: TextField(
                          controller: _codeController,
                          enabled: !_submitting,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          maxLength: 6,
                          showCursor: false,
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            filled: false,
                          ),
                          onChanged: (value) {
                            setState(() => _error = null);
                            if (value.length == 6) _verify();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: KingColors.danger),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _remaining > 0
                        ? '${_remaining.toString().padLeft(2, '0')} 秒后可重新获取'
                        : '可以重新获取验证码',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: _submitting ? null : _handleSecondaryAction,
                  child: Text(_remaining > 0 ? '收不到验证码？' : '重新获取'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _verify,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('验证并登录'),
            ),
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: ExpansionTile(
                key: const ValueKey('sms-test-scenarios'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                dense: true,
                leading: const Icon(
                  Icons.science_outlined,
                  size: 18,
                  color: KingColors.info,
                ),
                title: Text(
                  'UI 测试验证码',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '888888：通过；111111：错误；222222：结果未知；333333：过期。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
