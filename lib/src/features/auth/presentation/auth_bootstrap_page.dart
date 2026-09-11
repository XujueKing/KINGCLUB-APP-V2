import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_theme.dart';
import '../../../core/mock/mock_runtime.dart';
import '../data/auth_repository_provider.dart';
import '../domain/auth_repository.dart';
import 'legacy_welcome_page.dart';

class AuthBootstrapPage extends ConsumerWidget {
  const AuthBootstrapPage({
    super.key,
    required this.onAnonymous,
    required this.onAuthenticated,
    this.onOpenTerms,
    this.onOpenPrivacy,
  });

  final VoidCallback onAnonymous;
  final VoidCallback onAuthenticated;
  final VoidCallback? onOpenTerms;
  final VoidCallback? onOpenPrivacy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.read(authRepositoryProvider) is RealAuthRepository) {
      return _RealBootstrap(
        onAnonymous: onAnonymous,
        onAuthenticated: onAuthenticated,
        onOpenTerms: onOpenTerms,
        onOpenPrivacy: onOpenPrivacy,
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
    this.onOpenTerms,
    this.onOpenPrivacy,
  });
  final VoidCallback onAnonymous;
  final VoidCallback onAuthenticated;
  final VoidCallback? onOpenTerms;
  final VoidCallback? onOpenPrivacy;
  @override
  ConsumerState<_RealBootstrap> createState() => _RealBootstrapState();
}

class _RealBootstrapState extends ConsumerState<_RealBootstrap> {
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(_restore);
  }

  Future<void> _restore() async {
    if (!mounted || _loading) return;
    if (ref.read(authenticatedMemberProvider)?.isRealSession == true) {
      widget.onAuthenticated();
      return;
    }
    _loading = true;
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
      _showError(error.message);
    } catch (_) {
      _showError('网络连接暂不可用，点击继续重试');
    } finally {
      _loading = false;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => LegacyWelcomePage(
    onNext: _restore,
    onOpenTerms: widget.onOpenTerms ?? () {},
    onOpenPrivacy: widget.onOpenPrivacy ?? () {},
  );
}
