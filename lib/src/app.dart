import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design_system/king_theme.dart';
import 'navigation/app_router.dart';

class KingClubApp extends ConsumerWidget {
  const KingClubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'KingClub',
      debugShowCheckedModeBanner: false,
      theme: KingTheme.dark,
      routerConfig: router,
    );
  }
}
