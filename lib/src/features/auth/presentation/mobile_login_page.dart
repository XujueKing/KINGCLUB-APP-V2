import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_theme.dart';
import '../../../core/mock/mock_runtime.dart';

class MobileLoginPage extends ConsumerStatefulWidget {
  const MobileLoginPage({
    super.key,
    required this.onFlowCreated,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final ValueChanged<LoginFlowSnapshot> onFlowCreated;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  ConsumerState<MobileLoginPage> createState() => _MobileLoginPageState();
}

class _MobileLoginPageState extends ConsumerState<MobileLoginPage> {
  final _mobileController = TextEditingController();
  bool _accepted = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final mobile = _mobileController.text.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      setState(() => _error = '请输入正确的 11 位中国大陆手机号');
      return;
    }
    if (!_accepted) {
      setState(() => _error = '请先阅读并同意用户协议与隐私政策');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      final flow = await ref.read(mockRuntimeProvider).requestSms(mobile);
      if (!mounted) return;
      setState(() => _submitting = false);
      widget.onFlowCreated(flow);
    } on MockSmsRequestException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = switch (error.failure) {
          SmsRequestFailure.rateLimited => '请求过于频繁，请 60 秒后重试',
          SmsRequestFailure.offline => '网络暂时不可用，请检查后重试',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KingPageBody(
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.fromLTRB(24, 44, 24, 28),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: KingBrandMark(compact: true),
              ),
              const SizedBox(height: 52),
              Text('手机号登录', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                '登录或创建你的 KingClub 会员账户',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: KingColors.textSecondary),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _mobileController,
                enabled: !_submitting,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\s-]')),
                ],
                decoration: InputDecoration(
                  labelText: '手机号',
                  hintText: '请输入手机号',
                  prefixText: '+86  ',
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('获取验证码'),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SizedBox.square(
                      dimension: 40,
                      child: Checkbox(
                        value: _accepted,
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() {
                                _accepted = value ?? false;
                                _error = null;
                              }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '我已阅读并同意',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        TextButton(
                          onPressed: widget.onOpenTerms,
                          style: _inlineLinkStyle,
                          child: const Text('《用户协议》'),
                        ),
                        Text('和', style: Theme.of(context).textTheme.bodySmall),
                        TextButton(
                          onPressed: widget.onOpenPrivacy,
                          style: _inlineLinkStyle,
                          child: const Text('《隐私政策》'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: KingColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KingColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: KingColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '未注册的手机号将自动创建 KingClub 会员账户',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  dense: true,
                  title: Text(
                    'UI 测试说明',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '当前为离线 Mock，不发送真实短信。尾号 001 模拟限流，尾号 002 模拟离线。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle get _inlineLinkStyle => TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
    minimumSize: const Size(0, 36),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontSize: 13, height: 1.54),
  );
}
