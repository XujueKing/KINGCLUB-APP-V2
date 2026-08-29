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
  static const _styleOptions = [
    PreferenceOption(id: 'formal_cocktail', label: '高级酒会小礼服'),
    PreferenceOption(id: 'korean_modern', label: '韩式现代时尚风'),
    PreferenceOption(id: 'fresh', label: '小清新'),
    PreferenceOption(id: 'soft_glam', label: '纯欲风'),
    PreferenceOption(id: 'lolita', label: '洛丽塔风'),
    PreferenceOption(id: 'hanfu', label: '国风汉服'),
    PreferenceOption(id: 'cosplay', label: 'COSPLAY'),
    PreferenceOption(id: 'rugged', label: '痞帅风'),
    PreferenceOption(id: 'minimal_commute', label: '简约通勤'),
    PreferenceOption(id: 'streetwear', label: '街头潮流'),
    PreferenceOption(id: 'vintage', label: '复古风'),
    PreferenceOption(id: 'athleisure', label: '运动休闲'),
  ];

  static const _musicOptions = [
    PreferenceOption(id: 'house', label: 'HOUSE'),
    PreferenceOption(id: 'techno', label: 'TECHNO'),
    PreferenceOption(id: 'bounce', label: 'BOUNCE'),
    PreferenceOption(id: 'psy_trance', label: 'PSY TRANCE'),
    PreferenceOption(id: 'trance', label: 'TRANCE'),
    PreferenceOption(id: 'hip_hop', label: 'HIP-HOP'),
    PreferenceOption(id: 'dubstep', label: 'DUBSTEP'),
    PreferenceOption(id: 'big_room', label: 'BIG ROOM'),
    PreferenceOption(id: 'rnb', label: 'R&B'),
    PreferenceOption(id: 'pop', label: '流行'),
    PreferenceOption(id: 'live_band', label: '现场乐队'),
  ];

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
            options: _styleOptions,
            selected: _styles,
            onChanged: (value) => _toggle(_styles, value),
          ),
          const SizedBox(height: 28),
          PreferenceSection(
            title: '音乐类型',
            options: _musicOptions,
            selected: _music,
            onChanged: (value) => _toggle(_music, value),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _continue,
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
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
