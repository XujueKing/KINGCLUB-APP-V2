import 'features/messaging/data/push_registration_runtime.dart';
import 'features/messaging/data/chat_outbox_recovery.dart';
import 'features/messaging/data/chat_outbox.dart';
import 'core/design_system/king_text_scale.dart';
import 'features/messaging/data/call_presentation_lease.dart';
import 'features/messaging/data/foreground_call_inbox.dart';
import 'features/messaging/data/call_launch_coordinator.dart';
import 'features/messaging/data/call_repository.dart';
import 'features/messaging/data/messaging_repository.dart';
import 'features/messaging/presentation/call_page.dart';
import 'features/messaging/presentation/call_presentation_scope.dart';
import 'features/messaging/data/foreground_group_call_inbox.dart';
import 'features/messaging/data/group_call_repository.dart';
import 'features/messaging/data/group_chat_repository.dart';
import 'features/messaging/presentation/group_call_page.dart';
import 'features/messaging/presentation/group_call_invitation_dialog.dart';
import 'features/messaging/data/group_call_controller.dart';

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
  final _pushRegistration = PushRegistrationRuntime.configured();
  StreamSubscription<void>? _sessionChanges;
  StreamSubscription<Map<String, dynamic>>? _messages;
  bool _foreground = true;
  ForegroundCallInbox? _callInbox;
  ForegroundGroupCallInbox? _groupCallInbox;
  final _incomingPresentation = CallPresentationOwner();
  int _callGeneration = 0;
  Future<void>? _openingCallInbox;
  ChatOutboxRecovery? _outboxRecovery;
  int _outboxGeneration = 0;

  void _stopOutboxRecovery() {
    _outboxGeneration++;
    _outboxRecovery?.close();
    _outboxRecovery = null;
  }

  Future<void> _recoverOutbox() async {
    if (!mounted || !_foreground || kingclubApiBaseUrl.isEmpty) return;
    if (_outboxRecovery != null) {
      await _outboxRecovery!.notify();
      return;
    }
    final generation = ++_outboxGeneration;
    try {
      final repository = await MessagingRepository.open();
      if (!mounted || !_foreground || generation != _outboxGeneration) return;
      _outboxRecovery = ChatOutboxRecovery(
        repository,
        SecureChatOutbox(repository.account),
      )..start();
    } catch (_) {}
  }

  Future<void> _ensureCallInbox() => _openingCallInbox ??= _openCallInbox()
      .whenComplete(() => _openingCallInbox = null);

  Future<void> _openCallInbox() async {
    if (!mounted ||
        !_foreground ||
        kingclubApiBaseUrl.isEmpty ||
        ref.read(authenticatedMemberProvider)?.canEnterApp != true) {
      return;
    }
    if (_callInbox != null) {
      _callInbox!.foreground(true);
      _groupCallInbox?.foreground(true);
      return;
    }
    final generation = _callGeneration;
    final repository = CallRepository(await MessagingRepository.open());
    if (!mounted || !_foreground || generation != _callGeneration) return;
    final inbox = ForegroundCallInbox(
      launcher: CallLaunchCoordinator(repository),
      present: (prepared) async {
        if (!mounted ||
            !_foreground ||
            generation != _callGeneration ||
            ref.read(authenticatedMemberProvider)?.canEnterApp != true) {
          return false;
        }
        final profile = await repository.messaging.call('K260913000612', {
          'peer': prepared.call.caller,
        });
        final current = await repository.read(callId: prepared.call.id);
        if (!mounted ||
            !_foreground ||
            generation != _callGeneration ||
            current?.phase != CallPhase.ringing) {
          return false;
        }
        final navigator = ref
            .read(appRouterProvider)
            .routerDelegate
            .navigatorKey
            .currentState;
        if (navigator == null) return false;
        final lease = _incomingPresentation.acquire();
        if (lease == null) return false;
        try {
          final page = CallPage.native(
            repository: repository,
            initial: current!,
            peerName: profile['nickname'] as String? ?? prepared.call.caller,
            relay: prepared.relay,
          );
          await pushCallPresentation(
            navigator,
            page,
            lease,
            onDisposed: () => _incomingPresentation.release(lease),
          );
        } finally {
          _incomingPresentation.release(lease);
        }
        return true;
      },
    );
    _callInbox = inbox;
    final groups = GroupCallRepository(repository.messaging);
    _groupCallInbox = ForegroundGroupCallInbox(
      repository: groups,
      present: (call) async {
        if (!mounted || !_foreground || generation != _callGeneration) {
          return false;
        }
        final navigator = ref
            .read(appRouterProvider)
            .routerDelegate
            .navigatorKey
            .currentState;
        if (navigator == null) return false;
        final lease = _incomingPresentation.acquire();
        if (lease == null) return false;
        try {
          final invitation = GroupCallController.realtime(
            repository: groups,
            initial: call,
          );
          final interrupted = Completer<bool?>();
          final accepted = await Future.any<bool?>([
            showDialog<bool>(
              context: navigator.context,
              barrierDismissible: false,
              builder: (context) => GroupCallInvitationDialog(
                controller: invitation,
                onInterrupted: () {
                  _incomingPresentation.release(lease);
                  if (!interrupted.isCompleted) interrupted.complete(null);
                },
              ),
            ),
            interrupted.future,
          ]);
          if (!mounted ||
              !_foreground ||
              generation != _callGeneration ||
              accepted == null) {
            return false;
          }
          final current = await groups.read(call.id);
          if (!mounted ||
              !_foreground ||
              generation != _callGeneration ||
              current.endedAtMs != null ||
              current.participants
                      .singleWhere(
                        (p) => p.account == repository.messaging.account,
                      )
                      .phase !=
                  GroupCallPhase.invited) {
            return true;
          }
          if (!accepted) {
            await groups.declineInvitation(current);
          } else {
            await pushCallPresentation(
              navigator,
              GroupCallPage(
                repository: GroupChatRepository(repository.messaging),
                groupId: current.groupId,
                media: current.media,
                acceptedInvitation: current,
              ),
              lease,
              onDisposed: () => _incomingPresentation.release(lease),
            );
          }
          return true;
        } finally {
          _incomingPresentation.release(lease);
        }
      },
    );
    _groupCallInbox!.foreground(true);
    inbox.foreground(true);
  }

  void _clearCallInbox() {
    _stopOutboxRecovery();
    _callGeneration++;
    _incomingPresentation.reset();
    _callInbox?.close();
    _callInbox = null;
    _groupCallInbox?.close();
    _groupCallInbox = null;
  }

  Future<void> _syncRealtime() async {
    if (!_foreground || kingclubApiBaseUrl.isEmpty) return;
    final session = await SecureSessionStore().readSession();
    if (!mounted || !_foreground) return;
    if (session == null) {
      _clearCallInbox();
      KingclubRealtime.shared.stop();
      _messenger.currentState?.clearSnackBars();
      if (mounted) setState(() => _notice = null);
    } else {
      unawaited(_recoverOutbox());
      await KingclubRealtime.shared.start();
      await _ensureCallInbox();
    }
  }

  Map<String, dynamic>? _notice;
  Timer? _noticeTimer;
  String? _noticeSession;
  Future<void> _notification(Map<String, dynamic> event) async {
    if (event['eventType'] == 'connection.ready') {
      _pushRegistration?.sync();
      unawaited(_recoverOutbox());
    }
    if (event['eventType'] == 'auth.session.revoked') {
      final data = event['data'];
      final sessionId = data is Map ? data['sessionId'] : null;
      final store = SecureSessionStore();
      if (sessionId is! String ||
          !await store.clearRevokedSession(sessionId) ||
          await store.readSession() != null) {
        return;
      }
      if (mounted) {
        ref.read(authenticatedMemberProvider.notifier).clear();
        ref.read(appRouterProvider).go('/auth/mobile');
      }
      return;
    }
    if (event['eventType'] == 'chat.call.changed' ||
        event['eventType'] == 'chat.group.call.changed' ||
        event['eventType'] == 'connection.ready') {
      try {
        await _ensureCallInbox();
        _callInbox?.notify();
        _groupCallInbox?.notify();
      } catch (_) {}
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
    _sessionChanges = SecureSessionStore.changes.stream.listen((_) {
      _pushRegistration?.sync();
      _clearCallInbox();
      unawaited(_syncRealtime().catchError((Object _) {}));
    });
    _messages = KingclubRealtime.shared.events.listen(_notification);
    _pushRegistration?.sync();
    unawaited(_syncRealtime().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _pushRegistration?.close();
    _clearCallInbox();
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
    _pushRegistration?.foreground(_foreground);
    _callInbox?.foreground(_foreground);
    _groupCallInbox?.foreground(_foreground);
    if (_foreground) {
      _checkMobileWindow();
      unawaited(_syncRealtime().catchError((Object _) {}));
    } else {
      _stopOutboxRecovery();
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
      builder: (context, child) => KingTextScale(
        child: Stack(
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
      ),
    );
  }
}
