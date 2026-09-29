import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_call_page.dart';
import 'package:kingclub/src/features/messaging/presentation/call_presentation_scope.dart';
import 'package:kingclub/src/features/messaging/data/call_presentation_lease.dart';

void main() {
  testWidgets(
    'back from hosted member selection exits without an empty mini window',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
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
          GroupCallPage(
            repository: GroupChatRepository(
              MessagingRepository(
                account: 'me',
                call: (_, _) async => {'members': []},
              ),
            ),
            groupId: '00000000-0000-4000-8000-000000000001',
            media: CallMedia.audio,
          ),
          CallPresentationLease.acquire()!,
        ).then((_) => completed = true),
      );
      await tester.pumpAndSettle();
      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(completed, true);
      expect(find.byType(GroupCallPage), findsNothing);
      expect(find.byType(CallMiniWindow), findsNothing);
      CallPresentationLease.acquire()!.release();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'member selection reads real repository and retains start identity on retry',
    (tester) async {
      final starts = <Map<String, dynamic>>[];
      Object startError = const AuthFailure('UNAVAILABLE', '暂不可用');
      final repository = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, input) async {
            if (id == 'K260915000678') {
              starts.add(Map<String, dynamic>.from(input));
              throw startError;
            }
            return {
              'members': [
                {'account': 'me', 'nickname': '我'},
                {'account': 'friend', 'nickname': '测试朋友'},
              ],
            };
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupCallPage(
            repository: repository,
            groupId: '00000000-0000-4000-8000-000000000001',
            media: CallMedia.audio,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(starts, isEmpty);
      expect(find.text('测试朋友'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      await tester.tap(find.text('发起通话'));
      await tester.pumpAndSettle();
      expect(find.text('暂不可用'), findsOneWidget);
      expect(starts.single['invitees'], ['friend']);
      await tester.tap(find.text('发起通话'));
      await tester.pumpAndSettle();
      expect(starts.length, 2);
      expect(starts.first['requestId'], starts.last['requestId']);
      startError = TimeoutException('internal transport detail');
      await tester.tap(find.text('发起通话'));
      await tester.pumpAndSettle();
      expect(find.text('通话连接超时，请检查网络后重试'), findsOneWidget);
      expect(find.textContaining('internal transport'), findsNothing);
      startError = StateError('internal SDK failure');
      await tester.tap(find.text('发起通话'));
      await tester.pumpAndSettle();
      expect(find.text('通话连接失败，请返回后重试'), findsOneWidget);
      expect(find.textContaining('internal SDK'), findsNothing);
      expect(starts.map((start) => start['requestId']).toSet(), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
