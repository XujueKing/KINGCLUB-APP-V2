import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_details_page.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) save, {
    ValueChanged<bool>? changed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DirectChatDetailsPage(
          peerName: 'fixture',
          peerAccount: 'peer',
          onMutedChanged: changed,
          repository: MessagingRepository(
            account: 'me',
            call: (id, params) async {
              if (id == 'K260913000606') return save(params);
              return {};
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'mute requires explicit saved confirmation and remains retryable',
    (tester) async {
      var success = false;
      bool? changed;
      await show(
        tester,
        (_) async => {'saved': success},
        changed: (value) => changed = value,
      );
      final toggle = find.byKey(const ValueKey('direct-chat-details-muted'));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(changed, isNull);
      success = true;
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(changed, isTrue);
    },
  );

  testWidgets('session change while clear dialog is open prevents old write', (
    tester,
  ) async {
    var writes = 0;
    await show(tester, (_) async {
      writes++;
      return {'saved': true};
    });
    await tester.tap(find.byKey(const ValueKey('direct-chat-details-clear')));
    await tester.pumpAndSettle();
    SecureSessionStore.changes.add(null);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('direct-chat-details-confirm-clear')),
    );
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('登录状态已变化，请返回重新进入会话'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('direct-chat-details-avatar')),
      findsNothing,
    );
  });

  testWidgets('late save cannot update a replaced login or notify parent', (
    tester,
  ) async {
    final response = Completer<Map<String, dynamic>>();
    bool? changed;
    await show(
      tester,
      (_) => response.future,
      changed: (value) => changed = value,
    );
    await tester.tap(find.byKey(const ValueKey('direct-chat-details-muted')));
    await tester.pump();
    SecureSessionStore.changes.add(null);
    await tester.pump();
    response.complete({'saved': true});
    await tester.pumpAndSettle();
    expect(changed, isNull);
    expect(find.text('登录状态已变化，请返回重新进入会话'), findsOneWidget);
  });

  testWidgets('failed clear stays on details and can be retried', (
    tester,
  ) async {
    var writes = 0;
    await show(tester, (params) async {
      expect(params['hide'], isTrue);
      writes++;
      return {'saved': false};
    });
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('direct-chat-details-clear')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('direct-chat-details-confirm-clear')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('direct-chat-details-clear')),
        findsOneWidget,
      );
    }
    expect(writes, 2);
  });
}
