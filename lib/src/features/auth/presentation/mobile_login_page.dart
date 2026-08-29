import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mock/mock_runtime.dart';

class MobileLoginPage extends ConsumerStatefulWidget {
  const MobileLoginPage({
    super.key,
    required this.onBack,
    required this.onVerified,
  });

  final VoidCallback onBack;
  final ValueChanged<String> onVerified;

  @override
  ConsumerState<MobileLoginPage> createState() => _MobileLoginPageState();
}

class _MobileLoginPageState extends ConsumerState<MobileLoginPage> {
  static const _champagne = Color(0xFFC9B69E);
  static const _deepBrown = Color(0xFF24180A);
  static const _inputText = Color(0xFF2A1D11);

  final _mobileController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  LoginFlowSnapshot? _flow;
  Timer? _timer;
  int _remaining = 0;
  bool _requesting = false;
  bool _verifying = false;
  String? _mobileError;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _codeFocusNode.addListener(_handleCodeFocusChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mobileController.dispose();
    _codeController.dispose();
    _codeFocusNode
      ..removeListener(_handleCodeFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleCodeFocusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _requestCode() async {
    if (_requesting || _remaining > 0) return;
    final mobile = _mobileController.text.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      setState(() => _mobileError = '请输入正确的 11 位手机号');
      return;
    }
    setState(() {
      _requesting = true;
      _mobileError = null;
      _codeError = null;
    });
    try {
      final flow = await ref.read(mockRuntimeProvider).requestSms(mobile);
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _flow = flow;
        _requesting = false;
        _remaining = 60;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _remaining == 0) {
          timer.cancel();
          return;
        }
        setState(() => _remaining--);
      });
    } on MockSmsRequestException catch (error) {
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _mobileError = switch (error.failure) {
          SmsRequestFailure.rateLimited => '请求过于频繁，请 60 秒后重试',
          SmsRequestFailure.offline => '网络暂时不可用，请检查后重试',
        };
      });
    }
  }

  Future<void> _verify() async {
    if (_verifying || _flow == null || _codeController.text.length != 6) {
      return;
    }
    setState(() {
      _verifying = true;
      _codeError = null;
    });
    final outcome = await ref
        .read(mockRuntimeProvider)
        .verifyCode(flowId: _flow!.id, code: _codeController.text);
    if (!mounted) return;
    switch (outcome) {
      case CodeVerificationOutcome.verified:
        final onboardingId = ref.read(mockRuntimeProvider).startOnboarding();
        widget.onVerified(onboardingId);
      case CodeVerificationOutcome.invalid:
        _codeController.clear();
        setState(() {
          _verifying = false;
          _codeError = '验证码不正确，请重新输入';
        });
      case CodeVerificationOutcome.expired:
        _codeController.clear();
        setState(() {
          _verifying = false;
          _flow = null;
          _remaining = 0;
          _codeError = '验证码已过期，请重新获取';
        });
      case CodeVerificationOutcome.outcomeUnknown:
        _codeController.clear();
        ref.read(mockRuntimeProvider).clearFlow(_flow!.id);
        setState(() {
          _verifying = false;
          _flow = null;
          _remaining = 0;
          _codeError = '验证结果暂时无法确认，请重新获取';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextEnabled =
        _flow != null && _codeController.text.length == 6 && !_verifying;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final formWidth = constraints.maxWidth * 0.80;
              return Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 24,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 110),
                              SizedBox(
                                key: const ValueKey('mobile-login-brand-logo'),
                                width: constraints.maxWidth * 0.2933,
                                child: Semantics(
                                  label: 'King club',
                                  image: true,
                                  child: const Image(
                                    image: AssetImage(
                                      'assets/legacy/home/logo_2.png',
                                    ),
                                    fit: BoxFit.contain,
                                    excludeFromSemantics: true,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 54),
                              SizedBox(
                                key: const ValueKey('mobile-login-content'),
                                width: formWidth,
                                child: _form(context),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: formWidth,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      height: 50,
                                      child: FilledButton(
                                        key: const ValueKey(
                                          'mobile-login-next',
                                        ),
                                        onPressed: nextEnabled ? _verify : null,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _deepBrown,
                                          disabledBackgroundColor: _deepBrown
                                              .withValues(alpha: 0.62),
                                          foregroundColor: _champagne,
                                          disabledForegroundColor: _champagne
                                              .withValues(alpha: 0.46),
                                          shape: const StadiumBorder(),
                                          textStyle: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        child: _verifying
                                            ? const SizedBox.square(
                                                dimension: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: _champagne,
                                                    ),
                                              )
                                            : const Text('NEXT'),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'SHANGHAI . ZHUZHOU',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _champagne,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 25,
                    top: 35,
                    child: IconButton(
                      key: const ValueKey('mobile-login-back'),
                      onPressed: widget.onBack,
                      tooltip: '返回',
                      icon: const Image(
                        image: AssetImage('assets/legacy/friendship/back.png'),
                        width: 12,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    const labelStyle = TextStyle(
      color: _champagne,
      fontSize: 15,
      fontWeight: FontWeight.w400,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Mobile Phone:', style: labelStyle),
        const SizedBox(height: 10),
        _legacyInput(
          key: const ValueKey('mobile-login-phone-field'),
          controller: _mobileController,
          maxLength: 11,
          autofillHints: const [AutofillHints.telephoneNumber],
          onChanged: (_) {
            if (_flow != null) {
              ref.read(mockRuntimeProvider).clearFlow(_flow!.id);
            }
            _timer?.cancel();
            setState(() {
              _flow = null;
              _remaining = 0;
              _mobileError = null;
              _codeError = null;
              _codeController.clear();
            });
          },
        ),
        if (_mobileError != null) ...[
          const SizedBox(height: 6),
          Text(
            _mobileError!,
            style: const TextStyle(color: Color(0xFFFF7D93), fontSize: 12),
          ),
        ],
        const SizedBox(height: 18),
        const Text('Code:', style: labelStyle),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Row(
              children: [
                Expanded(
                  flex: 390,
                  child: _legacyInput(
                    key: const ValueKey('mobile-login-code-field'),
                    controller: _codeController,
                    focusNode: _codeFocusNode,
                    maxLength: 6,
                    hintText: _codeFocusNode.hasFocus ? null : '输入验证码',
                    borderRadius: BorderRadius.zero,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    onChanged: (_) => setState(() => _codeError = null),
                  ),
                ),
                Expanded(
                  flex: 210,
                  child: SizedBox.expand(
                    child: TextButton(
                      key: const ValueKey('mobile-login-request-code'),
                      onPressed: _requesting || _remaining > 0
                          ? null
                          : _requestCode,
                      style: TextButton.styleFrom(
                        backgroundColor: _deepBrown,
                        disabledBackgroundColor: _deepBrown,
                        foregroundColor: _champagne,
                        disabledForegroundColor: _champagne.withValues(
                          alpha: 0.65,
                        ),
                        shape: const RoundedRectangleBorder(),
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(
                        _requesting
                            ? '获取中…'
                            : _remaining > 0
                            ? '${_remaining}s'
                            : '获取验证码',
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_codeError != null) ...[
          const SizedBox(height: 6),
          Text(
            _codeError!,
            style: const TextStyle(color: Color(0xFFFF7D93), fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _legacyInput({
    required Key key,
    required TextEditingController controller,
    required int maxLength,
    required ValueChanged<String> onChanged,
    String? hintText,
    Iterable<String>? autofillHints,
    BorderRadius? borderRadius,
    FocusNode? focusNode,
  }) {
    return Container(
      key: key,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(25),
        gradient: const RadialGradient(
          center: Alignment.topLeft,
          radius: 1.65,
          colors: [Color(0xFFB8A289), Color(0xFF7E6951)],
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: !_verifying,
        keyboardType: TextInputType.number,
        autofillHints: autofillHints,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],
        maxLength: maxLength,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _inputText,
          fontSize: 19,
          fontWeight: FontWeight.w400,
        ),
        cursorColor: _inputText,
        decoration: InputDecoration(
          counterText: '',
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0x99422E19), fontSize: 15),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
