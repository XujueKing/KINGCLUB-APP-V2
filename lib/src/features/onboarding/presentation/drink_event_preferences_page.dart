import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_theme.dart';
import '../../../core/mock/mock_runtime.dart';
import 'onboarding_components.dart';

class DrinkEventPreferencesPage extends ConsumerStatefulWidget {
  const DrinkEventPreferencesPage({
    super.key,
    required this.flowId,
    required this.onBack,
    required this.onSubmitted,
    required this.onInvalidFlow,
  });

  final String flowId;
  final VoidCallback onBack;
  final VoidCallback onSubmitted;
  final VoidCallback onInvalidFlow;

  @override
  ConsumerState<DrinkEventPreferencesPage> createState() =>
      _DrinkEventPreferencesPageState();
}

class _DrinkEventPreferencesPageState
    extends ConsumerState<DrinkEventPreferencesPage> {
  final _drinks = <String>{};
  final _events = <String>{};
  bool _submitting = false;

  Future<void> _submit({bool skip = false}) async {
    if (_submitting) return;
    if (skip) {
      _drinks.clear();
      _events.clear();
    }
    setState(() => _submitting = true);
    await ref.read(mockRuntimeProvider).completeMockStep();
    if (!mounted) return;
    widget.onSubmitted();
  }

  void _toggle(Set<String> values, String value) {
    setState(
      () => values.contains(value) ? values.remove(value) : values.add(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.read(mockRuntimeProvider).hasOnboardingFlow(widget.flowId)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onInvalidFlow(),
      );
    }
    return OnboardingScaffold(
      step: 4,
      title: '完善兴趣偏好',
      subtitle: '选择酒类和活动偏好，或跳过后提交会员申请。请理性饮酒。',
      onBack: _submitting ? null : widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PreferenceSection(
            title: '酒类偏好',
            options: const ['无酒精', '啤酒', '葡萄酒', '威士忌', '鸡尾酒', '香槟'],
            selected: _drinks,
            onChanged: (value) => _toggle(_drinks, value),
          ),
          const SizedBox(height: 28),
          PreferenceSection(
            title: '希望参加的活动',
            options: const ['主题派对', '现场音乐', '好友聚会', '品鉴活动', '节日活动', 'DJ 夜'],
            selected: _events,
            onChanged: (value) => _toggle(_events, value),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('提交会员申请'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _submitting ? null : () => _submit(skip: true),
            child: const Text('跳过偏好并提交'),
          ),
          const SizedBox(height: 32),
          const KingStatusCard(
            key: ValueKey('drink-event-review-notice'),
            icon: Icons.fact_check_outlined,
            title: '提交后进入会员审核',
            message: '提交后将进入会员审核流程，最终结果请以审核状态页显示为准。',
            color: KingColors.info,
          ),
        ],
      ),
    );
  }
}
