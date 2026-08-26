import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mock/mock_runtime.dart';
import 'onboarding_components.dart';

class StyleMusicPreferencesPage extends ConsumerStatefulWidget {
  const StyleMusicPreferencesPage({
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
  ConsumerState<StyleMusicPreferencesPage> createState() =>
      _StyleMusicPreferencesPageState();
}

class _StyleMusicPreferencesPageState
    extends ConsumerState<StyleMusicPreferencesPage> {
  final _styles = <String>{};
  final _music = <String>{};
  bool _saving = false;

  Future<void> _continue({bool skip = false}) async {
    if (skip) {
      _styles.clear();
      _music.clear();
    }
    setState(() => _saving = true);
    await ref.read(mockRuntimeProvider).completeMockStep();
    if (!mounted) return;
    widget.onNext();
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
      step: 3,
      title: '你的风格偏好',
      subtitle: '可多选，也可以暂时跳过；偏好不作为实名或会员审核硬门槛。',
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PreferenceSection(
            title: '着装风格',
            options: const ['简约', '街头', '商务休闲', '复古', '派对', '运动'],
            selected: _styles,
            onChanged: (value) => _toggle(_styles, value),
          ),
          const SizedBox(height: 28),
          PreferenceSection(
            title: '音乐类型',
            options: const ['HOUSE', 'TECHNO', 'HIP-HOP', 'R&B', '流行', '电子'],
            selected: _music,
            onChanged: (value) => _toggle(_music, value),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _continue,
            child: _saving ? const _ButtonProgress() : const Text('下一步'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _saving ? null : () => _continue(skip: true),
            child: const Text('暂时跳过'),
          ),
        ],
      ),
    );
  }
}

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
