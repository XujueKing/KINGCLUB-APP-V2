import 'package:kingclub/src/core/design_system/king_notice.dart';

import 'dart:async';

import 'core/networking/kingclub_realtime.dart';
import 'core/session/secure_session_store.dart';
import 'features/club/data/storage_repository.dart';
import 'features/club/presentation/real_storage_pickup_page.dart';

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
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<void>? _sessionChanges;
  StreamSubscription<Map<String, dynamic>>? _messages;
  bool _foreground = true;
  Future<void> _syncRealtime() async {
    if (!_foreground || kingclubApiBaseUrl.isEmpty) return;
    final session = await SecureSessionStore().readSession();
    if (!mounted || !_foreground) return;
    if (session == null) {
      KingclubRealtime.shared.stop();
      _messenger.currentState?.clearSnackBars();
      if (mounted) setState(() => _notice = null);
    } else {
      await KingclubRealtime.shared.start();
    }
  }

  Map<String, dynamic>? _notice;
  Timer? _noticeTimer;
  String? _noticeSession;
  Future<void> _notification(Map<String, dynamic> event) async {
    if (event['eventType'] == 'auth.session.revoked') {
      await SecureSessionStore().clearSession();
      if (mounted) {
        ref.read(authenticatedMemberProvider.notifier).clear();
        ref.read(appRouterProvider).go('/auth/mobile');
      }
      return;
    }
    if (event['eventType'] != 'storage.changed') return;
    final data = event['data'];
    if (data is! Map ||
        data['payload'] is! Map ||
        data['payload']['itemRef'] is! String) {
      return;
    }
    final session = await SecureSessionStore().readSession();
    if (!mounted || !_foreground || session == null) return;
    _noticeSession = session['sessionId'] as String;
    setState(() => _notice = Map<String, dynamic>.from(data['payload'] as Map));
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  Future<void> _openNotice() async {
    final notice = _notice, noticeSession = _noticeSession;
    if (notice == null) return;
    setState(() => _notice = null);
    final session = await SecureSessionStore().readSession();
    if (!mounted ||
        session?['sessionId'] != noticeSession ||
        ref.read(authenticatedMemberProvider)?.canEnterApp != true) {
      return;
    }
    final repository = RealStorageRepository();
    try {
      final item = await repository.detail(notice['itemRef'] as String);
      final current = await SecureSessionStore().readSession();
      if (!mounted ||
          current?['sessionId'] != noticeSession ||
          ref.read(authenticatedMemberProvider)?.canEnterApp != true) {
        return;
      }
      ref
          .read(appRouterProvider)
          .routerDelegate
          .navigatorKey
          .currentState
          ?.push(
            MaterialPageRoute<void>(
              allowSnapshotting: false,
              builder: (_) =>
                  RealStoragePickupPage(item: item, repository: repository),
            ),
          );
    } catch (_) {
      (ref.read(appRouterProvider).routerDelegate.navigatorKey.currentContext ==
                  null
              ? null
              : KingNotice.of(
                  ref
                      .read(appRouterProvider)
                      .routerDelegate
                      .navigatorKey
                      .currentContext!,
                ))
          ?.showSnackBar(const SnackBar(content: Text('该记录暂不可查看，请刷新储物柜')));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionChanges = SecureSessionStore.changes.stream.listen(
      (_) => _syncRealtime(),
    );
    _messages = KingclubRealtime.shared.events.listen(_notification);
    _syncRealtime();
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _sessionChanges?.cancel();
    _messages?.cancel();
    KingclubRealtime.shared.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _checkMobileWindow();
      _syncRealtime();
    } else {
      KingclubRealtime.shared.stop();
    }
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
      scaffoldMessengerKey: _messenger,
      debugShowCheckedModeBanner: false,
      theme: KingTheme.dark,
      routerConfig: router,
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          if (_notice != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 16,
              right: 16,
              child: Material(
                color: const Color(0xF02A261E),
                borderRadius: BorderRadius.circular(14),
                elevation: 4,
                child: InkWell(
                  onTap: _openNotice,
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFFC9B69E),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '储物已核销，点击查看最新记录',
                            style: TextStyle(
                              color: Color(0xFFC9B69E),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Color(0xFFC9B69E),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
