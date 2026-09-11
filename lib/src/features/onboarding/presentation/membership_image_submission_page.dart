import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/king_theme.dart';
import '../../../core/mock/mock_runtime.dart';
import '../../auth/data/auth_repository_provider.dart';
import 'onboarding_components.dart';

class MembershipImageSubmissionPage extends ConsumerStatefulWidget {
  const MembershipImageSubmissionPage({
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
  ConsumerState<MembershipImageSubmissionPage> createState() =>
      _MembershipImageSubmissionPageState();
}

class _MembershipImageSubmissionPageState
    extends ConsumerState<MembershipImageSubmissionPage> {
  final _selectedSlots = <int>{};
  final _uploadingSlots = <int>{};
  final _slotErrors = <int, String>{};
  bool _saving = false;
  bool get _isReal => widget.flowId == 'real-registration';

  @override
  void initState() {
    super.initState();
    if (_isReal) return;
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
    if (_isReal) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('形象照片提交服务暂不可用，请稍后再试')));
      return;
    }
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
    });
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
    if (_isReal) return;
    if (_selectedSlots.length != 2) {
      setState(() {
        for (var i = 0; i < 2; i++) {
          if (!_selectedSlots.contains(i)) _slotErrors[i] = '请添加此槽位的照片';
        }
      });
      return;
    }
    setState(() => _saving = true);
    await ref
        .read(mockRuntimeProvider)
        .submitAppearanceAssessment(widget.flowId);
    if (!mounted) return;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _isReal
        ? ref.watch(authenticatedMemberProvider)?.needsImages == true
        : ref.read(mockRuntimeProvider).hasOnboardingFlow(widget.flowId);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          FilledButton(
            onPressed: _saving || _isReal ? null : _next,
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('提交并评分'),
          ),
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
          onTap: _saving || uploading ? null : () => _pick(index),
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
                if (uploading)
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
