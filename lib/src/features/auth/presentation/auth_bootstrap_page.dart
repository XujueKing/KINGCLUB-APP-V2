import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_theme.dart';
import '../../../core/mock/mock_runtime.dart';

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
