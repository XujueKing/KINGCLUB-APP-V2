import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/king_theme.dart';
import '../../../core/mock/mock_runtime.dart';

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
  static const _deepBrown = Color(0xFF24180A);

  final _nameController = TextEditingController();
  final _identityController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _identityFocusNode = FocusNode();
  bool _submitting = false;
  bool _adultConsent = false;

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
    });
    await ref.read(mockRuntimeProvider).completeMockStep();
    if (!mounted) return;
    widget.onNext();
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
    if (!ref.read(mockRuntimeProvider).hasOnboardingFlow(widget.flowId)) {
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          '步骤 1/4',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          onPressed: _submitting ? null : widget.onBack,
          tooltip: '返回',
          icon: Image.asset(
            'assets/legacy/friendship/back.png',
            width: 12,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LinearProgressIndicator(
                    value: 0.25,
                    minHeight: 3,
                    color: _gold,
                    backgroundColor: const Color(0xFF3A332C),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.08),
                  ColorFiltered(
                    colorFilter: const ColorFilter.mode(_gold, BlendMode.srcIn),
                    child: Image.asset(
                      'assets/legacy/onboarding/nonine.png',
                      width: 76,
                      height: 76,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 24),
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
                    height: 52,
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
                  const SizedBox(height: 14),
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
                    height: 52,
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
                  const SizedBox(height: 20),
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
                                  fontSize: 13,
                                  height: 1.55,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.09),
                  SizedBox(
                    width: controlWidth,
                    height: 52,
                    child: FilledButton(
                      key: const ValueKey('real-name-verify-button'),
                      onPressed: _submitting ? null : _requestVerification,
                      style: FilledButton.styleFrom(
                        backgroundColor: _deepBrown,
                        foregroundColor: _gold,
                        disabledBackgroundColor: const Color(0xFF17110A),
                        disabledForegroundColor: const Color(0x667C6D5A),
                        shape: const StadiumBorder(),
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
