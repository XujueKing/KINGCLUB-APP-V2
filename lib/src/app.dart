import 'features/messaging/data/push_registration_runtime.dart';
import 'features/messaging/data/background_notifications.dart';
import 'features/messaging/data/background_connection.dart';
import 'features/messaging/data/foreground_message_notice.dart';
import 'features/messaging/presentation/foreground_message_banner.dart';
import 'features/messaging/data/push_open_runtime.dart';
import 'features/messaging/data/push_open_store.dart';
import 'features/messaging/presentation/chat_route_presence.dart';
import 'features/messaging/presentation/direct_chat_page.dart';
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
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  static const _pushOpenChannel = MethodChannel('kingclub/push-open');
  PushOpenRuntime? _pushOpen;
  VoidCallback? _removePushRouteListener;
  StreamSubscription<void>? _sessionChanges;
  StreamSubscription<Map<String, dynamic>>? _messages;
  bool _foreground = true;
  final _backgroundNotifications = BackgroundNotifications();
  ForegroundCallInbox? _callInbox;
  ForegroundGroupCallInbox? _groupCallInbox;
  final _incomingPresentation = CallPresentationOwner();
  int _callGeneration = 0;
  Future<void>? _openingCallInbox;
  ChatOutboxRecovery? _outboxRecovery;
  int _outboxGeneration = 0;
  final _messageNoticeResolver = ForegroundMessageNoticeResolver();
  ForegroundMessageNotice? _messageNotice;
  PushOpenSession? _messageNoticeSession;
  Timer? _messageNoticeTimer;
  int _messageNoticeEpoch = 0;

  void _messageRouteChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _messageNotice == null || _messageNoticeSession == null) {
        return;
      }
      final navigator = ref
          .read(appRouterProvider)
          .routerDelegate
          .navigatorKey
          .currentState;
      if (navigator != null &&
          ChatRoutePresence.instance.isCurrent(navigator, (
            account: _messageNoticeSession!.account,
            target: _messageNotice!.target,
            group: _messageNotice!.group,
          ))) {
        _dismissMessageNotice();
      }
    });
  }

  void _dismissMessageNotice() {
    _messageNoticeTimer?.cancel();
    if (mounted) setState(() => _messageNotice = null);
  }

  Future<void> _foregroundMessage(Map<String, dynamic> event) async {
    final epoch = _messageNoticeEpoch;
    final session = await _pushReadySession();
    if (session == null || epoch != _messageNoticeEpoch) return;
    bool valid() =>
        mounted && _pushNavigationReady && epoch == _messageNoticeEpoch;
    try {
      final repository = await MessagingRepository.open();
      if (!valid() || repository.account != session.account) return;
      final notice = await _messageNoticeResolver.resolve(
        event: event,
        account: session.account,
        page: (offset) => repository
            .conversations(offset: offset)
            .timeout(const Duration(seconds: 5)),
        valid: valid,
      );
      if (notice == null ||
          !valid() ||
          await _pushReadySession() != session ||
          !valid()) {
        return;
      }
      final navigator = ref
          .read(appRouterProvider)
          .routerDelegate
          .navigatorKey
          .currentState;
      if (navigator == null ||
          ChatRoutePresence.instance.isCurrent(navigator, (
            account: session.account,
            target: notice.target,
            group: notice.group,
          ))) {
        return;
      }
      _messageNoticeSession = session;
      setState(() => _messageNotice = notice);
      _messageNoticeTimer?.cancel();
      _messageNoticeTimer = Timer(
        const Duration(seconds: 5),
        _dismissMessageNotice,
      );
    } catch (_) {
      /* Realtime list recovery still runs if notice lookup fails. */
    }
  }

  Future<void> _openMessageNotice() async {
    final notice = _messageNotice, expected = _messageNoticeSession;
    _dismissMessageNotice();
    if (notice == null ||
        expected == null ||
        await _pushReadySession() != expected) {
      return;
    }
    final navigator = ref
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentState;
    if (navigator == null) return;
    final identity = (
      account: expected.account,
      target: notice.target,
      group: notice.group,
    );
    if (ChatRoutePresence.instance.isCurrent(navigator, identity)) return;
    final route = MaterialPageRoute<void>(
      allowSnapshotting: false,
      builder: (_) => DirectChatPage(
        peerName: notice.name,
        peerAccount: notice.group ? null : notice.target,
        groupId: notice.group ? notice.target : null,
      ),
    );
    final release = ChatRoutePresence.instance.register(route, () => identity);
    unawaited(navigator.push<void>(route).whenComplete(release));
  }

  bool get _pushNavigationReady {
    if (!mounted ||
        !_foreground ||
        CallPresentationLease.isActive ||
        ref.read(authenticatedMemberProvider)?.canEnterApp != true) {
      return false;
    }
    final path = ref
        .read(appRouterProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
    return path.isNotEmpty &&
        !path.startsWith('/auth') &&
        !path.startsWith('/onboarding');
  }

  Future<PushOpenSession?> _pushReadySession() async {
    if (!_pushNavigationReady) return null;
    final session = await SecureSessionStore().readSession();
    final account = (session?['account'] as Map?)?['userAccount'];
    final id = session?['sessionId'];
    if (!_pushNavigationReady || account is! String || id is! String) {
      return null;
    }
    return (account: account, sessionId: id);
  }

  Future<bool> _openPushConversation(
    PushOpenTarget target,
    PushOpenSession expected,
  ) async {
    final current = await _pushReadySession();
    if (_pushOpen?.isCurrent(target) != true ||
        current != expected ||
        target.expiresAt <= DateTime.now().millisecondsSinceEpoch) {
      return false;
    }
    final navigator = ref
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentState;
    if (navigator == null) return false;
    final identity = (
      account: expected.account,
      target: target.target,
      group: target.group,
    );
    if (ChatRoutePresence.instance.isCurrent(navigator, identity)) return true;
    final route = MaterialPageRoute<void>(
      allowSnapshotting: false,
      settings: RouteSettings(
        name: 'push-chat:${target.group}:${target.target}',
      ),
      builder: (_) => DirectChatPage(
        peerName: target.group ? '群聊' : '聊天',
        peerAccount: target.group ? null : target.target,
        groupId: target.group ? target.target : null,
      ),
    );
    // Register before push/build so another notification in the same frame
    // cannot add a second copy while the page restores its repository.
    final release = ChatRoutePresence.instance.register(route, () => identity);
    unawaited(
      navigator.push<void>(route).whenComplete(() {
        release();
        _schedulePushOpen();
      }),
    );
    return true;
  }

  void _schedulePushOpen() {
    if (!mounted || _pushOpen == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_pushOpen?.sync());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

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

  bool _backgroundReceiverStarted = false;
  Future<void> _syncRealtime() async {
    if (kingclubApiBaseUrl.isEmpty) return;
    final session = await SecureSessionStore().readSession();
    if (!mounted) return;
    if (session == null) {
      _backgroundReceiverStarted = false;
      await BackgroundConnection.invoke('stop');
      _clearCallInbox();
      KingclubRealtime.shared.stop();
      _messenger.currentState?.clearSnackBars();
      if (mounted) setState(() => _notice = null);
    } else {
      if (_foreground) {
        _backgroundReceiverStarted = await BackgroundConnection.invoke('start');
      }
      if (!_foreground && _backgroundReceiverStarted) {
        KingclubRealtime.shared.stop();
        return;
      }
      unawaited(_recoverOutbox());
      await KingclubRealtime.shared.start();
      await _ensureCallInbox();
    }
  }

  Map<String, dynamic>? _notice;
  Timer? _noticeTimer;
  String? _noticeSession;
  Future<void> _notification(Map<String, dynamic> event) async {
    if (!_foreground && !_backgroundReceiverStarted) {
      _backgroundNotifications.notify(event);
    }
    if (event['eventType'] == 'chat.changed' ||
        event['eventType'] == 'chat.group.message') {
      unawaited(_foregroundMessage(event));
    }
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
    ChatRoutePresence.instance.addListener(_messageRouteChanged);
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _pushOpen = PushOpenRuntime(
        store: PushOpenStore(),
        takePending: () => _pushOpenChannel.invokeMethod<String>('takePending'),
        acknowledge: (raw) =>
            _pushOpenChannel.invokeMethod<void>('ackPending', raw),
        readySession: _pushReadySession,
        open: _openPushConversation,
      );
      _pushOpenChannel.setMethodCallHandler((call) async {
        if (call.method == 'changed') _schedulePushOpen();
      });
      final delegate = ref.read(appRouterProvider).routerDelegate;
      delegate.addListener(_schedulePushOpen);
      _removePushRouteListener = () =>
          delegate.removeListener(_schedulePushOpen);
      _schedulePushOpen();
    }
    _sessionChanges = SecureSessionStore.changes.stream.listen((_) {
      _backgroundNotifications.reset();
      _messageNoticeEpoch++;
      _messageNoticeResolver.clear();
      _dismissMessageNotice();
      _schedulePushOpen();
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
    _backgroundNotifications.reset();
    ChatRoutePresence.instance.removeListener(_messageRouteChanged);
    _messageNoticeEpoch++;
    _messageNoticeTimer?.cancel();
    _removePushRouteListener?.call();
    _pushOpen?.close();
    if (_pushOpen != null) _pushOpenChannel.setMethodCallHandler(null);
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
    _backgroundNotifications.foreground(_foreground);
    KingclubRealtime.shared.foreground(_foreground);
    _pushRegistration?.foreground(_foreground);
    _callInbox?.foreground(_foreground);
    _groupCallInbox?.foreground(_foreground);
    if (_foreground) {
      _schedulePushOpen();
      _checkMobileWindow();
      unawaited(_syncRealtime().catchError((Object _) {}));
    } else {
      _messageNoticeEpoch++;
      _dismissMessageNotice();
      _stopOutboxRecovery();
      unawaited(_handoffBackgroundReceiver());
      // Keep the authenticated socket while Android lets the process run.
      // Vendor push remains necessary after OS suspension/process death.
    }
  }

  Future<void> _handoffBackgroundReceiver() async {
    final running = await BackgroundConnection.invoke('running');
    if (!mounted || _foreground) return;
    _backgroundReceiverStarted = running;
    if (running) KingclubRealtime.shared.stop();
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
    ref.listen(authenticatedMemberProvider, (_, _) => _schedulePushOpen());
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
            Positioned(
              top: (100 * MediaQuery.sizeOf(context).width / 750).clamp(
                MediaQuery.paddingOf(context).top,
                double.infinity,
              ),
              left: 20 * MediaQuery.sizeOf(context).width / 750,
              right: 20 * MediaQuery.sizeOf(context).width / 750,
              child: ForegroundMessageBanner(
                visible: _messageNotice != null,
                onTap: _openMessageNotice,
                onDismiss: _dismissMessageNotice,
              ),
            ),
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
