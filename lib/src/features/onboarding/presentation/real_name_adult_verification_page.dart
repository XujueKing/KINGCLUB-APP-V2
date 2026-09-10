import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/king_theme.dart';
import '../../../core/mock/mock_runtime.dart';
import '../../auth/data/auth_repository_provider.dart';

class RealNameAdultVerificationPage extends ConsumerStatefulWidget {
  const RealNameAdultVerificationPage({
    super.key,
    required this.flowId,
    required this.onBack,
    required this.onNext,
    required this.onInvalidFlow,
  });

  final String flowId;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onInvalidFlow;

  @override
  ConsumerState<RealNameAdultVerificationPage> createState() =>
      _RealNameAdultVerificationPageState();
}

class _RealNameAdultVerificationPageState
    extends ConsumerState<RealNameAdultVerificationPage> {
  static const _gold = KingColors.brand;
  static const _actionBrown = Color(0xFF3B2814);

  final _nameController = TextEditingController();
  final _identityController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _identityFocusNode = FocusNode();
  bool _submitting = false;
  bool _adultConsent = false;
  String? _verificationError;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(_handleFieldFocusChanged);
    _identityFocusNode.addListener(_handleFieldFocusChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _identityController.dispose();
    _nameFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    _identityFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFieldFocusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _requestVerification() async {
    FocusScope.of(context).unfocus();
    if (widget.flowId == 'real-registration') {
      setState(() => _verificationError = '实名认证服务暂不可用，请稍后再试');
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      _showMessage('请输入身份证姓名');
      return;
    }
    if (_identityController.text.trim().length < 15) {
      _showMessage('请输入正确的身份证号码');
      return;
    }
    if (!_adultConsent) {
      _showMessage('请先阅读并同意成年声明');
      return;
    }
    setState(() {
      _submitting = true;
      _verificationError = null;
    });
    final outcome = await ref
        .read(mockRuntimeProvider)
        .submitPhotoIdentity(
          flowId: widget.flowId,
          name: _nameController.text.trim(),
          identityNumber: _identityController.text.trim().toUpperCase(),
        );
    if (!mounted) return;
    switch (outcome) {
      case PhotoIdentityOutcome.verifiedAdult:
        widget.onNext();
      case PhotoIdentityOutcome.identityMismatch:
        setState(() {
          _submitting = false;
          _verificationError = '照片与实名信息不一致，请确认信息后重新拍摄';
        });
      case PhotoIdentityOutcome.ageRestricted:
        setState(() {
          _submitting = false;
          _verificationError = '核验未通过：未满18周岁，暂不能注册会员';
        });
      case PhotoIdentityOutcome.retryableFailure:
        setState(() {
          _submitting = false;
          _verificationError = '照片不清晰或未检测到完整人脸，请重新拍摄';
        });
      case PhotoIdentityOutcome.outcomeUnknown:
        setState(() {
          _submitting = false;
          _verificationError = '核验结果确认中，请稍后重试，不需要重复上传';
        });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _formInputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF766451),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: const Color(0xFFBDA788),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: _gold, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: Color(0xFF2B2723)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReal = widget.flowId == 'real-registration';
    final validFlow = isReal
        ? ref.watch(authenticatedMemberProvider)?.needsIdentity == true
        : ref.read(mockRuntimeProvider).hasOnboardingFlow(widget.flowId);
    if (!validFlow) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onInvalidFlow(),
      );
    }
    final controlWidth = (MediaQuery.sizeOf(context).width - 48)
        .clamp(280.0, 480.0)
        .toDouble();
    final fieldWidth = (MediaQuery.sizeOf(context).width * 0.8)
        .clamp(280.0, 420.0)
        .toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    key: const ValueKey('real-name-step-header'),
                    width: controlWidth,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: -12,
                          child: IconButton(
                            onPressed: _submitting ? null : widget.onBack,
                            tooltip: '返回',
                            icon: Image.asset(
                              'assets/legacy/friendship/back.png',
                              width: 11,
                              height: 22,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                        const Text(
                          '身份资料',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                          ),
                        ),
                        const Positioned(
                          right: 0,
                          child: Text(
                            '1 / 4',
                            style: TextStyle(
                              color: Color(0xB3C9B69E),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: controlWidth,
                    child: const LinearProgressIndicator(
                      value: 0.25,
                      minHeight: 2,
                      color: _gold,
                      backgroundColor: Color(0xFF3A332C),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ColorFiltered(
                    colorFilter: const ColorFilter.mode(_gold, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/legacy/onboarding/nonine.png',
                      width: 90,
                      height: 90,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    '未满18岁未成年人\n不得饮酒注册会员',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _gold,
                      fontSize: 19,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: fieldWidth,
                    child: const Text(
                      'NAME:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _gold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: fieldWidth,
                    height: 46,
                    child: TextField(
                      key: const ValueKey('real-name-name-field'),
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        color: Color(0xFF4D4134),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      decoration: _formInputDecoration(
                        hint: _nameFocusNode.hasFocus ? '' : '请输入姓名',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: fieldWidth,
                    child: const Text(
                      'ID CARD:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _gold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: fieldWidth,
                    height: 46,
                    child: TextField(
                      key: const ValueKey('real-name-id-field'),
                      controller: _identityController,
                      focusNode: _identityFocusNode,
                      enabled: !_submitting,
                      enableSuggestions: false,
                      autocorrect: false,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      maxLength: 18,
                      buildCounter: (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                      style: const TextStyle(
                        color: Color(0xFF4D4134),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                      decoration: _formInputDecoration(
                        hint: _identityFocusNode.hasFocus ? '' : '请输入证件号码',
                      ),
                      onSubmitted: (_) => _requestVerification(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: controlWidth,
                    child: InkWell(
                      key: const ValueKey('real-name-notice-checkbox'),
                      onTap: _submitting
                          ? null
                          : () =>
                                setState(() => _adultConsent = !_adultConsent),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _adultConsent
                                      ? _gold
                                      : Colors.transparent,
                                  border: Border.all(color: _gold, width: 1.5),
                                ),
                                child: _adultConsent
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: Color(0xFF24180A),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                '我已阅读并同意：本人已满18周岁，未成年人禁止进入本娱乐场所，遵守店内相关管理规定。',
                                style: TextStyle(
                                  color: _gold,
                                  fontSize: 12.5,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_verificationError case final error?) ...[
                    SizedBox(
                      key: const ValueKey('photo-identity-error'),
                      width: controlWidth,
                      child: Text(
                        error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: KingColors.danger,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: fieldWidth,
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('real-name-verify-button'),
                      onPressed: _submitting ? null : _requestVerification,
                      style: FilledButton.styleFrom(
                        backgroundColor: _actionBrown,
                        foregroundColor: _gold,
                        disabledBackgroundColor: const Color(0xFF17110A),
                        disabledForegroundColor: const Color(0x667C6D5A),
                        shape: const StadiumBorder(),
                        side: BorderSide(
                          color: _submitting
                              ? _gold.withValues(alpha: 0.18)
                              : _gold.withValues(alpha: 0.55),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                color: _gold,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ColorFiltered(
                                  colorFilter: const ColorFilter.mode(
                                    _gold,
                                    BlendMode.srcIn,
                                  ),
                                  child: Image.asset(
                                    'assets/legacy/onboarding/camera.png',
                                    width: 24,
                                    height: 20,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  '拍照上传核验',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SHANGHAI . ZHUZHOU',
                    style: TextStyle(color: _gold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
