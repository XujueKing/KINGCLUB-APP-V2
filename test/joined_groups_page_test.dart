import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_directory_store.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/joined_groups_page.dart';

Map<String, dynamic> row(String id) => {
  'groupId': id,
  'groupName': 'Group $id',
  'memberCount': 2,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('directory survives reopening and is account isolated', () async {
    await GroupDirectoryStore('A').save([row('cleared')]);
    expect(await GroupDirectoryStore('A').read(), [row('cleared')]);
    expect(await GroupDirectoryStore('B').read(), isEmpty);
    await GroupDirectoryStore('A').save([]);
    expect(await GroupDirectoryStore('A').read(), isEmpty);
  });

  testWidgets('group change during fetch discards old result and refreshes', (
    tester,
  ) async {
    final events = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(events.close);
    final old = Completer<Map<String, dynamic>>();
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: JoinedGroupsPage(
          repository: GroupChatRepository(
            MessagingRepository(
              account: 'A',
              call: (_, _) {
                reads++;
                if (reads == 1) return old.future;
                return Future.value({
                  'items': [row('current')],
                  'nextCursor': null,
                });
              },
            ),
          ),
          events: events.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    events.add({'eventType': 'chat.group.changed'});
    await tester.pump();
    old.complete({
      'items': [row('left')],
      'nextCursor': null,
    });
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Group left'), findsNothing);
    expect(find.text('Group current'), findsOneWidget);
    expect(await GroupDirectoryStore('A').read(), [row('current')]);
  });

  testWidgets('offline failure retains joined groups without recent messages', (
    tester,
  ) async {
    await GroupDirectoryStore('A').save([row('cleared')]);
    final response = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: JoinedGroupsPage(
          repository: GroupChatRepository(
            MessagingRepository(
              account: 'A',
              call: (id, params) {
                expect(id, 'K260913000618');
                return response.future;
              },
            ),
          ),
          events: const Stream.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Group cleared'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    response.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Group cleared'), findsOneWidget);
    expect(find.text('暂时无法更新群聊，点击重试'), findsOneWidget);
  });

  testWidgets('pagination deduplicates and authoritative empty removes cache', (
    tester,
  ) async {
    final events = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(events.close);
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: JoinedGroupsPage(
          repository: GroupChatRepository(
            MessagingRepository(
              account: 'A',
              call: (id, params) async {
                reads++;
                if (reads == 1) {
                  return {
                    'items': [row('one')],
                    'nextCursor': '7',
                  };
                }
                if (reads == 2) {
                  expect(params['before'], '7');
                  return {
                    'items': [row('one'), row('two')],
                    'nextCursor': null,
                  };
                }
                expect(params['before'], isNull);
                return {'items': [], 'nextCursor': null};
              },
            ),
          ),
          events: events.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看更多'));
    await tester.pumpAndSettle();
    expect(find.text('Group one'), findsOneWidget);
    expect(find.text('Group two'), findsOneWidget);
    expect(await GroupDirectoryStore('A').read(), hasLength(2));
    events.add({'eventType': 'chat.group.changed'});
    await tester.pumpAndSettle();
    expect(find.text('Group one'), findsNothing);
    expect(find.text('暂无加入的群聊'), findsOneWidget);
    expect(await GroupDirectoryStore('A').read(), isEmpty);
  });

  testWidgets('account change rejects late results and clears visible cache', (
    tester,
  ) async {
    await GroupDirectoryStore('A').save([row('old')]);
    final response = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: JoinedGroupsPage(
          repository: GroupChatRepository(
            MessagingRepository(account: 'A', call: (_, _) => response.future),
          ),
          events: const Stream.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    SecureSessionStore.changes.add(null);
    await tester.pumpAndSettle();
    response.complete({
      'items': [row('late')],
      'nextCursor': null,
    });
    await tester.pumpAndSettle();
    expect(find.text('Group old'), findsNothing);
    expect(find.text('Group late'), findsNothing);
    expect(find.text('登录状态已变化，请重新进入'), findsOneWidget);
    expect(await GroupDirectoryStore('A').read(), [row('old')]);
  });
}
