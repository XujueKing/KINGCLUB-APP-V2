import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_theme.dart';
import '../../../core/mock/mock_runtime.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/real_identity_repository.dart';
import 'onboarding_components.dart';

class MembershipImageSubmissionPage extends ConsumerStatefulWidget {
  const MembershipImageSubmissionPage({
    super.key,
    required this.flowId,
    required this.onBack,
    required this.onNext,
    required this.onInvalidFlow,
    this.onSwitchMobile,
  });

  final String flowId;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onInvalidFlow;
  final Future<void> Function()? onSwitchMobile;

  @override
  ConsumerState<MembershipImageSubmissionPage> createState() =>
      _MembershipImageSubmissionPageState();
}

class _MembershipImageSubmissionPageState
    extends ConsumerState<MembershipImageSubmissionPage> {
  final _selectedSlots = <int>{};
  final _uploadingSlots = <int>{};
  final _slotErrors = <int, String>{};
  bool _saving = false;
  bool _switchingMobile = false;
  bool _loading = false;
  bool _completed = false;
  String? _error;
  String _assessmentState = 'draft';
  int _version = 1;
  String? _submissionKey;
  final _previews = <int, String>{};
  bool get _isReal => widget.flowId == 'real-registration';

  @override
  void initState() {
    super.initState();
    if (_isReal) {
      Future.microtask(_loadReal);
      return;
    }
    final snapshot = ref
        .read(mockRuntimeProvider)
        .onboardingSnapshot(widget.flowId);
    if (snapshot?.photoSlots.contains(RegistrationPhotoSlot.portrait) ??
        false) {
      _selectedSlots.add(0);
    }
    if (snapshot?.photoSlots.contains(RegistrationPhotoSlot.outfit) ?? false) {
      _selectedSlots.add(1);
    }
  }

  Future<void> _pick(int slot) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: KingColors.elevated,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍摄照片'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    setState(() {
      _uploadingSlots.add(slot);
      _slotErrors.remove(slot);
      _error = null;
    });
    if (_isReal) {
      try {
        final repository = ref.read(realIdentityRepositoryProvider);
        final bytes = await repository.capture(
          source: action == 'gallery'
              ? ImageSource.gallery
              : ImageSource.camera,
        );
        if (bytes == null) return;
        await repository.upload(
          bytes,
          (_, _) {},
          appearanceSlot: slot == 0 ? 'portrait' : 'outfit',
        );
        _submissionKey = null;
        await _loadReal();
      } on AuthFailure catch (error) {
        if (mounted) setState(() => _slotErrors[slot] = error.message);
      } catch (_) {
        if (mounted) setState(() => _slotErrors[slot] = '照片处理或上传失败，请重新选择');
      } finally {
        if (mounted) setState(() => _uploadingSlots.remove(slot));
      }
      return;
    }
    final uploaded = await ref
        .read(mockRuntimeProvider)
        .stageRegistrationPhoto(
          flowId: widget.flowId,
          slot: slot == 0
              ? RegistrationPhotoSlot.portrait
              : RegistrationPhotoSlot.outfit,
        );
    if (!mounted) return;
    setState(() {
      _uploadingSlots.remove(slot);
      if (uploaded) {
        _selectedSlots.add(slot);
        _slotErrors.remove(slot);
      } else {
        _slotErrors[slot] = '照片上传失败，请重新选择';
      }
    });
  }

  Future<void> _next() async {
    if (_selectedSlots.length != 2) {
      setState(() {
        for (var i = 0; i < 2; i++) {
          if (!_selectedSlots.contains(i)) _slotErrors[i] = '请添加此槽位的照片';
        }
      });
      return;
    }
    setState(() => _saving = true);
    if (_isReal) {
      try {
        _submissionKey ??= const Uuid().v4();
        await ref
            .read(realIdentityRepositoryProvider)
            .submitAppearance(_version, _submissionKey!);
        await _loadReal();
        final repository =
            ref.read(authRepositoryProvider) as RealAuthRepository;
        _completed = true;
        final member = await repository.refreshMembership();
        if (!mounted) return;
        if (member.canEnterApp) {
          widget.onNext();
        } else {
          setState(() => _completed = false);
        }
      } on AuthFailure catch (error) {
        if (mounted) setState(() => _error = error.message);
        await _loadReal();
      } catch (_) {
        if (mounted) setState(() => _error = '暂未确认评分结果，请点击刷新，照片无需重新上传');
      } finally {
        if (mounted) {
          setState(() {
            _saving = false;
            if (_assessmentState != 'approved') _completed = false;
          });
        }
      }
      return;
    }
    await ref
        .read(mockRuntimeProvider)
        .submitAppearanceAssessment(widget.flowId);
    if (!mounted) return;
    widget.onNext();
  }

  Future<void> _loadReal() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final repository = ref.read(realIdentityRepositoryProvider);
      final result = await repository.appearanceStatus();
      if (!mounted) return;
      setState(() {
        _assessmentState = '${result['state']}';
        _version = (result['version'] as num).toInt();
        _selectedSlots.clear();
        _previews.clear();
        for (final photo in (result['photos'] as List? ?? [])) {
          final slot = photo['slot'] == 'portrait' ? 0 : 1;
          _selectedSlots.add(slot);
          _previews[slot] = repository.previewUrl('${photo['previewPath']}');
          if (photo['state'] == 'rejected') {
            _slotErrors[slot] = photo['resultCode'] == 'PORTRAIT_FACE_TOO_SMALL'
                ? '人脸距离过远，请换一张正面清晰照片'
                : '请上传仅有本人、面部清晰的照片';
          }
        }
      });
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '照片资料加载失败，请点击刷新重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid =
        _switchingMobile ||
        _completed ||
        (_isReal
            ? (ref.watch(authenticatedMemberProvider)?.needsImages == true ||
                  ref.watch(authenticatedMemberProvider)?.registrationStatus ==
                      'pending_review')
            : ref.read(mockRuntimeProvider).hasOnboardingFlow(widget.flowId));
    if (!valid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onInvalidFlow();
      });
    }
    return OnboardingScaffold(
      step: 2,
      title: '完善会员形象资料',
      subtitle: '请添加两张近期清晰照片，仅用于会员审核。',
      onBack: widget.onBack,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onSwitchMobile != null)
            TextButton(
              key: const ValueKey('switch-registration-mobile'),
              onPressed: _switchingMobile
                  ? null
                  : () async {
                      setState(() => _switchingMobile = true);
                      try {
                        await widget.onSwitchMobile!();
                      } finally {
                        if (mounted) setState(() => _switchingMobile = false);
                      }
                    },
              child: const Text('其它账号登录'),
            ),
          SizedBox(
            height: 45,
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  _saving ||
                      _loading ||
                      _uploadingSlots.isNotEmpty ||
                      (_isReal &&
                          (_selectedSlots.length != 2 ||
                              [
                                'processing',
                                'unknown',
                                'pending_review',
                                'approved',
                              ].contains(_assessmentState)))
                  ? null
                  : _next,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _assessmentState == 'pending_review'
                          ? '已提交 · 等待审核'
                          : _assessmentState == 'processing'
                          ? '正在评分'
                          : '提交并评分',
                    ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'SHANGHAI . ZHUZHOU',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xB3C9B69E), fontSize: 13),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isReal && (_error != null || _assessmentState != 'draft')) ...[
            Text(
              _error ??
                  switch (_assessmentState) {
                    'pending_review' => '资料已提交人工审核，也可以替换照片后重新评分。',
                    'changes_required' => '请按照片提示重新上传，已通过的实名无需重做。',
                    'processing' => '正在确认三张照片的评分结果，请稍后刷新。',
                    'unknown' => '评分结果待确认，请联系客服，避免重复提交。',
                    'approved' => '会员审核已通过。',
                    _ => '',
                  },
              style: const TextStyle(color: KingColors.brand),
            ),
            TextButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _error = null);
                      await _loadReal();
                      if (_assessmentState == 'approved') {
                        _completed = true;
                        await (ref.read(
                          authRepositoryProvider,
                        ) as RealAuthRepository).refreshMembership();
                        if (mounted) widget.onNext();
                      }
                    },
              child: Text(_loading ? '正在刷新' : '刷新状态'),
            ),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _slot(0, '正面清晰照', Icons.face_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _slot(1, '半身/全身照', Icons.accessibility_new)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '照片要求：本人、近期、清晰、无严重遮挡。照片不使用美颜，将用于会员形象评分与审核。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _slot(int index, String label, IconData icon) {
    final selected = _selectedSlots.contains(index);
    final uploading = _uploadingSlots.contains(index);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap:
              _saving ||
                  uploading ||
                  _loading ||
                  [
                    'processing',
                    'unknown',
                    'approved',
                  ].contains(_assessmentState)
              ? null
              : () => _pick(index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: KingColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? KingColors.success : KingColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!uploading && _previews[index] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _previews[index]!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_outlined, size: 48),
                    ),
                  )
                else if (uploading)
                  const SizedBox.square(
                    dimension: 42,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    selected ? Icons.check_circle_outline : icon,
                    size: 48,
                    color: selected ? KingColors.success : KingColors.brand,
                  ),
                const SizedBox(height: 12),
                Text(label, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(
                  uploading
                      ? '压缩并上传中…'
                      : selected
                      ? '已上传 · 点击替换'
                      : '点击添加',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (_slotErrors[index] case final error?) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: const TextStyle(color: KingColors.danger, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
