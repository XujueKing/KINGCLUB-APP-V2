import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_details_page.dart';

void main() {
  testWidgets(
    'group switches acknowledge owner settings, retain values on failure and reject late session results',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      var muted = false;
      var pinned = true;
      var fail = false;
      Completer<Map<String, dynamic>>? pending;
      final calls = <Map<String, dynamic>>[];
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, params) async {
            expect(params['groupId'], 'group-real');
            if (id == 'K260913000619') {
              return {'groupName': '真实群', 'members': []};
            }
            if (id == 'K260913000621') {
              return {
                'settings': {'muted': muted, 'pinned': pinned},
              };
            }
            if (id == 'K260913000623') {
              calls.add(params);
              if (fail) throw StateError('保存失败');
              if (pending != null) return pending.future;
              if (params.containsKey('muted')) muted = params['muted'] as bool;
              if (params.containsKey('pinned')) {
                pinned = params['pinned'] as bool;
              }
              return {'saved': true};
            }
            throw StateError('Unexpected $id');
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDetailsPage(groupId: 'group-real', repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      final mute = find.byKey(const ValueKey('group-details-muted'));
      final pin = find.byKey(const ValueKey('group-details-pinned'));
      expect(tester.widget<Switch>(mute).value, false);
      expect(tester.widget<Switch>(pin).value, true);
      await tester.tap(mute);
      await tester.pumpAndSettle();
      expect(calls.single, {'groupId': 'group-real', 'muted': true});
      expect(tester.widget<Switch>(mute).value, true);
      fail = true;
      await tester.tap(pin);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(pin).value, true);
      expect(find.textContaining('保存失败'), findsOneWidget);
      fail = false;
      pending = Completer<Map<String, dynamic>>();
      await tester.tap(pin);
      await tester.pump();
      expect(tester.widget<Switch>(pin).onChanged, isNull);
      SecureSessionStore.changes.add(null);
      await tester.pump();
      expect(find.text('真实群'), findsNothing);
      pending.complete({'saved': true});
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNothing);
      expect(find.text('登录状态已变化'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
