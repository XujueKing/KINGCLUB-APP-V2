import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mock/mock_runtime.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/real_identity_repository.dart';
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
  ];

  final _styles = <String>{};
  final _music = <String>{};
  bool _saving = false;
  bool get _isReal => widget.flowId == 'real-registration';
  Map<String, dynamic> _draft = {
    'styles': <String>[],
    'music': <String>[],
    'drinks': <String>[],
    'events': <String>[],
  };
  int _version = 1;
  String? _error;
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    if (_isReal) Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(realIdentityRepositoryProvider)
          .preferences();
      if (!mounted) return;
      setState(() {
        _draft = Map<String, dynamic>.from(result['preferences'] as Map);
        _version = (result['version'] as num).toInt();
        _styles
          ..clear()
          ..addAll(List<String>.from(_draft['styles'] ?? []));
        _music
          ..clear()
          ..addAll(List<String>.from(_draft['music'] ?? []));
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '爱好资料加载失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _continue({bool skip = false}) async {
    if (skip) {
      _styles.clear();
      _music.clear();
    }
    setState(() => _saving = true);
    if (_isReal) {
      try {
        await ref
            .read(realIdentityRepositoryProvider)
            .savePreferences(
              {..._draft, 'styles': _styles.toList(), 'music': _music.toList()},
              _version,
              finalize: false,
            );
        if (mounted) widget.onNext();
      } on AuthFailure catch (error) {
        if (mounted) setState(() => _error = error.message);
      } catch (_) {
        if (mounted) setState(() => _error = '保存失败，请重试');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }
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
    if (_isReal
        ? ref.watch(authenticatedMemberProvider)?.needsPreferences != true
        : !ref.read(mockRuntimeProvider).hasOnboardingFlow(widget.flowId)) {
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
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: _saving ? null : _load,
              child: const Text('重新加载'),
            ),
          ],
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
            onPressed: _saving || (_isReal && !_loaded) ? null : _continue,
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
            child: _saving ? const _ButtonProgress() : const Text('下一步'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _saving || (_isReal && !_loaded)
                ? null
                : () => _continue(skip: true),
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
