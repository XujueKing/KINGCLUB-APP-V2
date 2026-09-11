import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design_system/king_theme.dart';
import 'navigation/app_router.dart';
import 'features/auth/data/auth_repository_provider.dart';

class KingClubApp extends ConsumerStatefulWidget {
  const KingClubApp({super.key});
  @override
  ConsumerState<KingClubApp> createState() => _KingClubAppState();
}

class _KingClubAppState extends ConsumerState<KingClubApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkMobileWindow();
  }

  Future<void> _checkMobileWindow() async {
    if (ref.read(authenticatedMemberProvider)?.isRealSession != true) return;
    final repository = ref.read(authRepositoryProvider);
    if (repository is RealAuthRepository &&
        !await repository.canResumeWithoutSms() &&
        mounted) {
      ref.read(authenticatedMemberProvider.notifier).clear();
      ref.read(appRouterProvider).go('/auth/mobile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'KingClub',
      debugShowCheckedModeBanner: false,
      theme: KingTheme.dark,
      routerConfig: router,
    );
  }
}
