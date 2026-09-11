import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_theme.dart';
import '../../../core/design_system/registration_input_style.dart';
import '../../../core/mock/mock_runtime.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/real_identity_repository.dart';

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
  String? _progress;
  bool _checkingOutcome = false;
  bool _verificationCompleted = false;

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
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (widget.flowId == 'real-registration') {
      await _verifyReal();
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

  Future<void> _verifyReal() async {
    final name = _nameController.text.trim();
    final idCard = _identityController.text.trim().toUpperCase();
    if (!_checkingOutcome &&
        (name.length < 2 || !RegExp(r'^\d{17}[0-9X]$').hasMatch(idCard))) {
      _showMessage('请输入身份证姓名和18位身份证号码');
      return;
    }
    setState(() {
      _submitting = true;
      _verificationError = null;
      _progress = '读取核验状态…';
    });
    final repository = ref.read(realIdentityRepositoryProvider);
    try {
      final existing = await repository.status();
      if (!mounted) return;
      if (['verified', 'processing', 'unknown'].contains(existing['state'])) {
        await _handleRealResult(existing);
        return;
      }
      _checkingOutcome = false;
      if (existing['providerAvailable'] != true) {
        throw const AuthFailure(
          'IDENTITY_PROVIDER_UNAVAILABLE',
          '实名认证服务尚未开通，请稍后再试',
        );
      }
      setState(() => _progress = '拍照并压缩…');
      final photo = await repository.capture();
      if (photo == null || !mounted) return;
      setState(() => _progress = '上传照片…');
      final photoId = await repository.upload(photo, (sent, total) {
        if (mounted && total > 0) {
          setState(() => _progress = '上传照片 ${(sent * 100 / total).round()}%');
        }
      });
      if (!mounted) return;
      setState(() {
        _progress = '正在核验…';
        _checkingOutcome = true;
      });
      final result = await repository.submit(
        photoId: photoId,
        name: name,
        idCard: idCard,
        idempotencyKey: const Uuid().v4(),
      );
      if (mounted) await _handleRealResult(result);
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _verificationError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _verificationError = '拍照或核验未完成，请检查相机权限和网络后重试');
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _handleRealResult(Map<String, dynamic> result) async {
    if (result['state'] == 'verified') {
      final auth = ref.read(authRepositoryProvider);
      if (auth is RealAuthRepository) await auth.refreshMembership();
      if (mounted) {
        _verificationCompleted = true;
        widget.onNext();
      }
      return;
    }
    setState(() {
      _checkingOutcome = ['processing', 'unknown'].contains(result['state']);
      _verificationError = _checkingOutcome
          ? '核验结果确认中，请刷新结果，无需重复拍照。'
          : '核验未通过，请检查姓名、身份证号码并拍摄清晰正面照片。';
    });
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
      decoration: registrationInputDecoration(height: 46),
      alignment: Alignment.center,
      child: TextField(
        key: ValueKey(keyName),
        controller: controller,
        focusNode: focus,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
        decoration: registrationTextDecoration(
          hint: focus.hasFocus ? '' : hint,
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
        ? (_verificationCompleted ||
              _submitting ||
              ref.watch(authenticatedMemberProvider)?.needsIdentity == true)
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
            padding: const EdgeInsets.only(top: 30, bottom: 27),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                minHeight: (constraints.maxHeight - 57).clamp(
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
                      alignment: Alignment.topCenter,
                      children: [
                        if (_progress != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _progress!,
                              style: const TextStyle(
                                color: _gold,
                                fontSize: 13,
                              ),
                            ),
                          ),
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
                                width: 64,
                                height: 64,
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
                            SizedBox(
                              width: fieldWidth,
                              child: const Padding(
                                padding: EdgeInsets.only(top: 15, bottom: 20),
                                child: Text(
                                  '根据《中华人民共和国未成年人保护法》第三十七条禁止向未成年人出售烟酒，经营者应当在显著位置设置不向未成年人出售烟酒的标志；对难以判明是否已成年的，应当要求其出示身份证件。请实名验证会员身份，确保年满18岁。',
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                    color: Color(0xCCC9B69E),
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
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
                          height: 45,
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
                                      Text(
                                        _checkingOutcome ? '刷新核验结果' : '人脸核验',
                                        style: const TextStyle(
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
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xB3C9B69E),
                            fontSize: 13,
                          ),
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
