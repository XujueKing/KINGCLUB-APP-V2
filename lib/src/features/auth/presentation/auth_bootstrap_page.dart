import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_theme.dart';
import '../../../core/mock/mock_runtime.dart';
import '../data/auth_repository_provider.dart';
import '../domain/auth_repository.dart';

class AuthBootstrapPage extends ConsumerWidget {
  const AuthBootstrapPage({
    super.key,
    required this.onAnonymous,
    required this.onAuthenticated,
  });

  final VoidCallback onAnonymous;
  final VoidCallback onAuthenticated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.read(authRepositoryProvider) is RealAuthRepository) {
      return _RealBootstrap(
        onAnonymous: onAnonymous,
        onAuthenticated: onAuthenticated,
      );
    }
    ref.listen(bootstrapOutcomeProvider, (previous, next) {
      next.whenData((outcome) {
        switch (outcome) {
          case BootstrapOutcome.anonymous:
            onAnonymous();
          case BootstrapOutcome.authenticated:
            onAuthenticated();
          case BootstrapOutcome.offline:
          case BootstrapOutcome.fatal:
            break;
        }
      });
    });

    final state = ref.watch(bootstrapOutcomeProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const KingBrandMark(),
                const SizedBox(height: 40),
                state.when(
                  loading: () => const Column(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 16),
                      Text('正在安全检查登录状态'),
                    ],
                  ),
                  data: (_) => const SizedBox(height: 48),
                  error: (_, _) => Column(
                    children: [
                      const KingStatusCard(
                        icon: Icons.error_outline,
                        title: '暂时无法启动',
                        message: '请检查网络连接后重试。',
                        color: KingColors.danger,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(bootstrapOutcomeProvider),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RealBootstrap extends ConsumerStatefulWidget {
  const _RealBootstrap({
    required this.onAnonymous,
    required this.onAuthenticated,
  });
  final VoidCallback onAnonymous;
  final VoidCallback onAuthenticated;
  @override
  ConsumerState<_RealBootstrap> createState() => _RealBootstrapState();
}

class _RealBootstrapState extends ConsumerState<_RealBootstrap> {
  String? _error;
  @override
  void initState() {
    super.initState();
    Future.microtask(_restore);
  }

  Future<void> _restore() async {
    if (mounted) setState(() => _error = null);
    try {
      final result = await (ref.read(
        authRepositoryProvider,
      ) as RealAuthRepository).restoreSession();
      if (!mounted) return;
      if (result == null) {
        ref.read(authenticatedMemberProvider.notifier).clear();
        widget.onAnonymous();
      } else {
        widget.onAuthenticated();
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法读取注册进度，请检查网络后重试');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const KingBrandMark(),
              const SizedBox(height: 32),
              if (_error == null) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('正在恢复登录和注册进度'),
              ] else ...[
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _restore, child: const Text('重试')),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
