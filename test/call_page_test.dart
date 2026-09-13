import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/call_page.dart';
import 'package:kingclub/src/features/messaging/data/call_state_controller.dart';
import 'package:kingclub/src/features/messaging/data/call_media_session.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/native_call_media.dart';

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
  Future<void> sync() async {}
  @override
  Future<void> close() async {}
}

void main() {
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
