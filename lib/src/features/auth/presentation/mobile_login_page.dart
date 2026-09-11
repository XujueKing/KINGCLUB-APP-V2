import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/registration_input_style.dart';
import '../data/auth_repository_provider.dart';
import '../domain/auth_repository.dart';

class MobileLoginPage extends ConsumerStatefulWidget {
  const MobileLoginPage({
    super.key,
    required this.onBack,
    required this.onVerified,
    this.onAuthenticatedMember,
    this.onRegistrationStatus,
  });

  final VoidCallback onBack;
  final ValueChanged<String> onVerified;
  final VoidCallback? onAuthenticatedMember;
  final VoidCallback? onRegistrationStatus;

  @override
  ConsumerState<MobileLoginPage> createState() => _MobileLoginPageState();
}

class _MobileLoginPageState extends ConsumerState<MobileLoginPage> {
  static const _champagne = Color(0xFFC9B69E);
  static const _buttonGold = Color(0xFF24180A);
  static const _buttonGoldDisabled = Color(0xFF292929);
  static const _actionText = Color(0xAAC9B69E);
  static const _disabledActionText = Color(0xFF777777);
  static const _inputText = Color(0xFF2A1D11);

  final _mobileController = TextEditingController();
  final _codeController = TextEditingController();
  final _mobileFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();
  AuthSmsChallenge? _flow;
  Timer? _timer;
  int _remaining = 0;
  bool _requesting = false;
  bool _verifying = false;
  String? _mobileError;
  String? _codeError;

  bool get _validMobile =>
      RegExp(r'^1[3-9]\d{9}$').hasMatch(_mobileController.text);
  bool get _validCode => RegExp(r'^\d{6}$').hasMatch(_codeController.text);
  bool get _canVerify =>
      _validMobile && _validCode && !_requesting && !_verifying;

  @override
  void initState() {
    super.initState();
    _mobileFocusNode.addListener(_handleInputFocusChanged);
    _codeFocusNode.addListener(_handleCodeFocusChanged);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mobileController.dispose();
    _codeController.dispose();
    _mobileFocusNode
      ..removeListener(_handleInputFocusChanged)
      ..dispose();
    _codeFocusNode
      ..removeListener(_handleCodeFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleCodeFocusChanged() {
    if (mounted) setState(() {});
  }

  void _handleInputFocusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _requestCode() async {
    if (_requesting || _remaining > 0) return;
    final mobile = _mobileController.text.replaceAll(RegExp(r'[\s-]'), '');
    if (!_validMobile) {
      setState(() => _mobileError = '请输入正确的 11 位手机号');
      return;
    }
    setState(() {
      _requesting = true;
      _mobileError = null;
      _codeError = null;
    });
    try {
      final flow = await ref.read(authRepositoryProvider).requestSms(mobile);
      if (!mounted) return;
      if (_mobileController.text != mobile) {
        setState(() => _requesting = false);
        return;
      }
      _timer?.cancel();
      setState(() {
        _flow = flow;
        _requesting = false;
        _remaining = flow.retryAfterSeconds;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _remaining == 0) {
          timer.cancel();
          return;
        }
        setState(() => _remaining--);
      });
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _mobileError = switch (error.code) {
          'AUTH_SMS_RATE_LIMITED' => '请求过于频繁，请稍后重试',
          'SMS_PROVIDER_ERROR' => '短信发送失败，请稍后重试',
          'SMS_ROUTE_UNAVAILABLE' => '短信服务正在配置，请稍后重试',
          _ => error.message,
        };
      });
    }
  }

  Future<void> _verify() async {
    if (!_canVerify) {
      return;
    }
    setState(() {
      _verifying = true;
      _codeError = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .login(
            mobile: _mobileController.text.replaceAll(RegExp(r'[\s-]'), ''),
            challengeId: _flow?.id ?? '',
            code: _codeController.text,
          );
      if (!mounted) return;
      if (result.canEnterApp && widget.onAuthenticatedMember != null) {
        widget.onAuthenticatedMember!();
      } else if (result.isRealSession) {
        if (result.needsIdentity) {
          widget.onVerified('real-registration');
        } else if (widget.onRegistrationStatus != null) {
          widget.onRegistrationStatus!();
        } else {
          throw const AuthFailure('MEMBERSHIP_RESTRICTED', '请先完成会员注册审核');
        }
      } else if (result.onboardingFlowId != null) {
        widget.onVerified(result.onboardingFlowId!);
      } else {
        throw const AuthFailure('MEMBERSHIP_INVALID', '会员状态暂时无法确认，请稍后重试');
      }
    } on AuthFailure catch (error) {
      if (!mounted) return;
      final expired =
          error.code == 'AUTH_CHALLENGE_EXPIRED' ||
          error.code == 'AUTH_CHALLENGE_INVALID' ||
          error.code == 'AUTH_CHALLENGE_LOCKED';
      _codeController.clear();
      setState(() {
        _verifying = false;
        if (expired) {
          _flow = null;
          _remaining = 0;
        }
        _codeError = switch (error.code) {
          'AUTH_CODE_INVALID' => '验证码不正确，请重新输入',
          'IDENTITY_BINDING_CONFLICT' => '会员账号绑定异常，请联系客服处理',
          'AUTH_CHALLENGE_EXPIRED' => '验证码已过期，请重新获取',
          'AUTH_CHALLENGE_LOCKED' => '错误次数过多，请重新获取',
          'IDENTITY_AUTHORITY_UNAVAILABLE' => '会员服务暂时不可用，请稍后重试',
          _ => error.message,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _codeError = '登录暂时未完成，请稍后重试';
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextEnabled = _canVerify;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          key: const ValueKey('mobile-login-dismiss-keyboard'),
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(
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
                                const SizedBox(height: 70),
                                SizedBox(
                                  key: const ValueKey(
                                    'mobile-login-brand-logo',
                                  ),
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
                                        height: 45,
                                        child: FilledButton(
                                          key: const ValueKey(
                                            'mobile-login-next',
                                          ),
                                          onPressed: nextEnabled
                                              ? _verify
                                              : null,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: _buttonGold,
                                            disabledBackgroundColor:
                                                _buttonGoldDisabled,
                                            foregroundColor: _actionText,
                                            disabledForegroundColor:
                                                _disabledActionText,
                                            shape: const StadiumBorder(),
                                            textStyle: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
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
                                      const SizedBox(height: 10),
                                      const Text(
                                        'SHANGHAI . ZHUZHOU',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Color(0xB3C9B69E),
                                          fontSize: 13,
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
                      left: KingBackButton.leftOffset(context),
                      top: KingBackButton.safeAreaOffset.dy,
                      child: KingBackButton(
                        key: const ValueKey('mobile-login-back'),
                        onPressed: widget.onBack,
                      ),
                    ),
                  ],
                );
              },
            ),
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
          focusNode: _mobileFocusNode,
          maxLength: 11,
          hintText: _mobileFocusNode.hasFocus ? null : '请输入电话号码',
          autofillHints: const [AutofillHints.telephoneNumber],
          onChanged: (_) {
            _timer?.cancel();
            setState(() {
              _flow = null;
              _remaining = 0;
              _mobileError = null;
              _codeError = null;
              _codeController.clear();
            });
          },
          fontSize: 21,
        ),
        if (_mobileError != null) ...[
          const SizedBox(height: 6),
          Text(
            _mobileError!,
            style: const TextStyle(color: Color(0xFFFF7D93), fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        const Text('Code:', style: labelStyle),
        const SizedBox(height: 10),
        SizedBox(
          height: 45,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22.5),
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
                    fontSize: 20,
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
                        backgroundColor: _buttonGold,
                        disabledBackgroundColor: _buttonGoldDisabled,
                        foregroundColor: _actionText,
                        disabledForegroundColor: _disabledActionText,
                        shape: const RoundedRectangleBorder(),
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
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
    double fontSize = 21,
  }) {
    return Container(
      key: key,
      height: 45,
      decoration: registrationInputDecoration(
        height: 45,
        borderRadius: borderRadius,
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
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          color: _inputText,
          fontWeight: FontWeight.w400,
        ).copyWith(fontSize: fontSize),
        cursorColor: _inputText,
        decoration: registrationTextDecoration(
          hint: hintText,
          horizontalPadding: 12,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
