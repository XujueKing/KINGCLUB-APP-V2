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
  static const _actionBrown = Color(0xFF24180A);

  final _nameController = TextEditingController();
  final _identityController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _identityFocusNode = FocusNode();
  bool _submitting = false;
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

  Widget _field({
    required String keyName,
    required TextEditingController controller,
    required FocusNode focus,
    required String hint,
    bool identity = false,
  }) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const RadialGradient(
          center: Alignment.topLeft,
          radius: 1,
          colors: [Color(0xFFB8A289), Color(0xFF7E6951)],
        ),
      ),
      child: TextField(
        key: ValueKey(keyName),
        controller: controller,
        focusNode: focus,
        enabled: !_submitting,
        enableSuggestions: false,
        autocorrect: false,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: identity
            ? TextInputType.visiblePassword
            : TextInputType.name,
        textInputAction: identity ? TextInputAction.done : TextInputAction.next,
        maxLength: identity ? 18 : null,
        buildCounter: (
          _, {
          required currentLength,
          required isFocused,
          maxLength,
        }) => null,
        style: const TextStyle(
          color: _actionBrown,
          fontSize: 21,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: focus.hasFocus ? '' : hint,
          hintStyle: const TextStyle(color: Color(0x99422E19), fontSize: 16),
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
        onSubmitted: (_) {
          if (identity) {
            _requestVerification();
          } else {
            _identityFocusNode.requestFocus();
          }
        },
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onInvalidFlow();
      });
    }
    final width = MediaQuery.sizeOf(context).width;
    final contentWidth = (width * .88).clamp(0.0, 528.0).toDouble();
    final fieldWidth = (width * .8).clamp(0.0, 480.0).toDouble();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.only(top: 30, bottom: 50),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 80).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: contentWidth,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            const SizedBox(height: 30),
                            ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                _gold,
                                BlendMode.srcIn,
                              ),
                              child: Image.asset(
                                'assets/legacy/onboarding/nonine.png',
                                width: 90,
                                height: 90,
                              ),
                            ),
                            const SizedBox(height: 25),
                            const Text(
                              '未满18岁未成年人\n不得饮酒注册会员',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _gold,
                                fontSize: 20,
                                height: 1.4,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 15, bottom: 20),
                              child: Text(
                                '根据《中华人民共和国未成年人保护法》第三十七条禁止向未成年人出售烟酒，经营者应当在显著位置设置不向未成年人出售烟酒的标志；对难以判明是否已成年的，应当要求其出示身份证件。请实名验证会员身份，确保年满18岁。',
                                textAlign: TextAlign.justify,
                                style: TextStyle(
                                  color: Color(0xCCC9B69E),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const Text(
                              'NAME:',
                              style: TextStyle(color: _gold, fontSize: 14),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: fieldWidth,
                              child: _field(
                                keyName: 'real-name-name-field',
                                controller: _nameController,
                                focus: _nameFocusNode,
                                hint: '身份证姓名',
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'ID CARD:',
                              style: TextStyle(color: _gold, fontSize: 14),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: fieldWidth,
                              child: _field(
                                keyName: 'real-name-id-field',
                                controller: _identityController,
                                focus: _identityFocusNode,
                                hint: '身份证号码',
                                identity: true,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          child: IconButton(
                            tooltip: '返回',
                            onPressed: _submitting ? null : widget.onBack,
                            icon: Image.asset(
                              'assets/legacy/friendship/back.png',
                              width: 10,
                              height: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: Column(
                      children: [
                        if (_verificationError case final error?) ...[
                          Text(
                            error,
                            key: const ValueKey('photo-identity-error'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: KingColors.danger,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton(
                            key: const ValueKey('real-name-verify-button'),
                            onPressed: _submitting
                                ? null
                                : _requestVerification,
                            style: FilledButton.styleFrom(
                              backgroundColor: _actionBrown,
                              foregroundColor: const Color(0xABC9B69E),
                              disabledBackgroundColor: _actionBrown,
                              disabledForegroundColor: const Color(0x61C9B69E),
                              shape: const StadiumBorder(),
                              side: BorderSide.none,
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
                                          width: 22.5,
                                          height: 18.6,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        '人脸核验',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'SHANGHAI . ZHUZHOU',
                          style: TextStyle(color: _gold, fontSize: 14),
                        ),
                      ],
                    ),
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
