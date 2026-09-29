import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/call_page.dart';
import 'package:kingclub/src/features/messaging/data/call_state_controller.dart';
import 'package:kingclub/src/features/messaging/data/call_media_session.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/native_call_media.dart';
import 'package:kingclub/src/features/messaging/data/call_presentation_lease.dart';
import 'package:kingclub/src/features/messaging/presentation/call_presentation_scope.dart';

const id = '00000000-0000-4000-8000-000000000001';
Map<String, dynamic> snapshot(String phase, int version) => {
  'callId': id,
  'caller': 'a',
  'callee': 'b',
  'mediaKind': 'audio',
  'phase': phase,
  'version': version,
  'deadlineMs': 9999999999999,
};

class Session extends CallMediaSession {
  Session(CallRepository repository, CallSnapshot call)
    : super(
        repository: repository,
        call: call,
        mediaFactory: (_) => NativeCallMedia(
          video: false,
          iceServers: [],
          capture: (_) async => throw StateError('unused'),
        ),
      );
  @override
  Future<void> start() async {}
  @override
  Future<void> sync({bool renewLease = true}) async {}
  @override
  Future<void> close() async {}
}

void main() {
  for (final terminal in ['remote', 'logout']) {
    testWidgets(
      '$terminal removes a minimized incoming call and releases its lease',
      (tester) async {
        var server = snapshot('ringing', 0);
        final changes = StreamController<void>.broadcast();
        final navigator = GlobalKey<NavigatorState>();
        final repository = CallRepository(
          MessagingRepository(
            account: 'b',
            call: (_, _) async => {'call': server},
          ),
        );
        final controller = CallStateController(
          repository: repository,
          initial: CallSnapshot.parse(server, 'b'),
          sessionChanges: changes.stream,
          sessionFactory: (_, _) =>
              throw StateError('Incoming call must not capture'),
        );
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            builder: (_, child) => CallPresentationHost(child: child!),
            home: const Scaffold(body: Text('home')),
          ),
        );
        var completed = false;
        unawaited(
          pushCallPresentation(
            navigator.currentState!,
            CallPage(controller: controller, peerName: 'friend'),
            CallPresentationLease.acquire()!,
          ).then((_) => completed = true),
        );
        await tester.pumpAndSettle();
        // Exercise the visible iPhone back button as well as system back below.
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(find.byType(CallMiniWindow), findsOneWidget);
        if (terminal == 'remote') {
          server = {
            ...snapshot('ended', 1),
            'endedAtMs': 9999999999998,
            'endReason': 'cancelled',
          };
          unawaited(controller.refresh());
        } else {
          SecureSessionStore.changes.add(null);
        }
        await tester.pumpAndSettle();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(completed, true);
        expect(controller.isClosed, true);
        expect(find.byType(CallMiniWindow), findsNothing);
        CallPresentationLease.acquire()!.release();
        await tester.pumpWidget(const SizedBox());
        await changes.close();
      },
    );
  }

  testWidgets(
    'back minimizes; navigating away and restoring keeps one session; hangup releases it',
    (tester) async {
      var server = snapshot('connecting', 1);
      var opens = 0, ends = 0, completed = false;
      final changes = StreamController<void>.broadcast();
      final navigator = GlobalKey<NavigatorState>();
      final repository = CallRepository(
        MessagingRepository(
          account: 'a',
          call: (method, params) async {
            if (method == 'K260913000612' ||
                !params.containsKey('action') && method != 'K260913000645') {
              return <String, dynamic>{};
            }
            if (method == 'K260913000645') return {'call': server};
            ends++;
            server = {
              ...snapshot('ended', 2),
              'endedAtMs': 9999999999998,
              'endReason': 'hangup',
            };
            return server;
          },
        ),
      );
      final controller = CallStateController(
        repository: repository,
        initial: CallSnapshot.parse(server, 'a'),
        sessionChanges: changes.stream,
        outgoingAttempt: true,
        sessionFactory: (call, _) {
          opens++;
          return Session(repository, call);
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => CallPresentationHost(child: child!),
          home: const Scaffold(body: Text('chat list')),
        ),
      );
      navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('chat'))),
      );
      await tester.pumpAndSettle();
      final lease = CallPresentationLease.acquire()!;
      final done = pushCallPresentation(
        navigator.currentState!,
        CallPage(controller: controller, peerName: 'friend'),
        lease,
      ).then((_) => completed = true);
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(CallPage));
      expect(opens, 1);
      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(CallMiniWindow), findsOneWidget);
      expect(ends, 0);
      expect(completed, false);
      expect(CallPresentationLease.acquire(), isNull);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('chat list'), findsOneWidget);
      expect(identical(tester.state(find.byType(CallPage)), state), true);
      await tester.drag(find.byType(CallMiniWindow), const Offset(60, 80));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('call-restore')));
      await tester.pumpAndSettle();
      expect(find.byType(CallMiniWindow), findsNothing);
      expect(identical(tester.state(find.byType(CallPage)), state), true);
      expect(opens, 1);
      await tester.tap(find.byTooltip('挂断'));
      await tester.pumpAndSettle();
      // Drain stream cancellation futures created outside the fake clock.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(completed, true);
      await done;
      expect(ends, 1);
      expect(completed, true);
      expect(find.byType(CallPage), findsNothing);
      CallPresentationLease.acquire()!.release();
      await tester.pumpWidget(const SizedBox());
      await changes.close();
    },
  );

  testWidgets(
    'incoming page keeps explicit accept after lost acknowledgement and does not claim connected',
    (tester) async {
      final changes = StreamController<void>.broadcast();
      var server = snapshot('ringing', 0);
      var lost = true, opens = 0;
      final repository = CallRepository(
        MessagingRepository(
          account: 'b',
          call: (method, params) async {
            if (method == 'K260913000612' ||
                !params.containsKey('action') && method != 'K260913000645') {
              return <String, dynamic>{};
            }
            if (method == 'K260913000645') return {'call': server};
            server = snapshot('connecting', 1);
            if (lost) {
              lost = false;
              throw const AuthFailure('NETWORK_ERROR', 'lost');
            }
            return server;
          },
        ),
      );
      final controller = CallStateController(
        repository: repository,
        initial: CallSnapshot.parse(server, 'b'),
        sessionChanges: changes.stream,
        sessionFactory: (call, _) {
          opens++;
          return Session(repository, call);
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CallPage(controller: controller, peerName: 'Test friend'),
        ),
      );
      await tester.pump();
      expect(find.text('邀请你通话'), findsOneWidget);
      expect(opens, 0);
      await tester.tap(find.byTooltip('接听'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byTooltip('接听'), findsOneWidget);
      expect(opens, 0);
      await tester.tap(find.byTooltip('接听'));
      await tester.pump();
      await tester.pump();
      expect(opens, 1);
      expect(find.text('正在连接'), findsOneWidget);
      expect(find.text('通话中'), findsNothing);
      changes.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.text('通话已结束'), findsOneWidget);
      expect(find.byTooltip('接听'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await changes.close();
    },
  );
}
