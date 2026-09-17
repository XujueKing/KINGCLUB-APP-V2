import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_details_page.dart';

void main() {
  testWidgets('read updates reuse avatars, membership updates refresh them', (
    tester,
  ) async {
    final events = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(events.close);
    var profiles = 0, reads = 0;
    final repo = GroupChatRepository(
      MessagingRepository(
        account: 'me',
        call: (id, _) async {
          if (id == 'K260913000612') {
            profiles++;
            return {'nickname': 'Peer'};
          }
          if (id == 'K260913000619') {
            reads++;
            return {
              'groupName': 'Test group',
              'ownerAccount': 'me',
              'metadataVersion': 1,
              'members': [
                {
                  'account': 'peer',
                  'nickname': 'Peer',
                  'role': 'member',
                  'membershipVersion': 0,
                },
              ],
            };
          }
          if (id == 'K260913000621') {
            return {
              'settings': {'muted': false, 'pinned': false},
            };
          }
          return {};
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailsPage(
          groupId: 'group-real',
          repository: repo,
          events: events.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(profiles, 1);
    events.add({
      'eventType': 'chat.group.changed',
      'data': {'groupId': 'another'},
    });
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(profiles, 1);
    events.add({
      'eventType': 'chat.group.read',
      'data': {'groupId': 'another'},
    });
    await tester.pumpAndSettle();
    expect(reads, 1);
    for (var i = 0; i < 3; i++) {
      events.add({
        'eventType': 'chat.group.read',
        'data': {'groupId': 'group-real'},
      });
      await tester.pumpAndSettle();
    }
    expect(reads, 4);
    expect(profiles, 1);
    events.add({'eventType': 'chat.group.changed'});
    await tester.pumpAndSettle();
    expect(profiles, 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'notification bursts coalesce and stale details never replace current data',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      addTearDown(events.close);
      final stale = Completer<Map<String, dynamic>>();
      final latest = Completer<Map<String, dynamic>>();
      var detailReads = 0, historyReads = 0;
      Map<String, dynamic> details(String name) => {
        'groupName': name,
        'ownerAccount': 'me',
        'metadataVersion': 1,
        'members': [],
      };
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, _) async {
            if (id == 'K260913000619') {
              detailReads++;
              if (detailReads == 2) return stale.future;
              if (detailReads == 3) return latest.future;
              return details('Initial group');
            }
            if (id == 'K260913000621') {
              historyReads++;
              return {
                'settings': {'muted': false, 'pinned': false},
              };
            }
            return {};
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDetailsPage(
            groupId: 'group-real',
            repository: repo,
            events: events.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      events.add({'eventType': 'chat.group.changed'});
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        events.add({'eventType': 'chat.group.changed'});
      }
      await tester.pump();
      expect(detailReads, 2);
      expect(historyReads, 2);
      stale.complete(details('Stale group'));
      await tester.pump();
      expect(detailReads, 3);
      expect(find.text('Stale group'), findsNothing);
      latest.complete(details('Latest group'));
      await tester.pumpAndSettle();
      expect(find.text('Latest group'), findsOneWidget);
      expect(historyReads, 3);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'metadata refresh retains scroll while denied access removes details',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final events = StreamController<Map<String, dynamic>>.broadcast();
      Completer<Map<String, dynamic>>? pending;
      Map<String, dynamic> details(String name) => {
        'groupName': name,
        'ownerAccount': 'me',
        'metadataVersion': 1,
        'members': List.generate(
          20,
          (i) => {
            'account': 'member-$i',
            'nickname': 'Member $i',
            'role': 'member',
            'membershipVersion': 0,
          },
        ),
      };
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, _) async {
            if (id == 'K260913000619') {
              return pending?.future ?? Future.value(details('Before'));
            }
            if (id == 'K260913000621') {
              return {
                'settings': {'muted': false, 'pinned': false},
              };
            }
            return {};
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDetailsPage(
            groupId: 'group-real',
            repository: repo,
            events: events.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -450));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final offset = scroll.position.pixels;
      expect(offset, greaterThan(0));
      pending = Completer<Map<String, dynamic>>();
      events.add({'eventType': 'chat.group.changed'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(scroll.position.pixels, offset);
      expect(scroll.position.maxScrollExtent, greaterThan(offset));
      pending.complete(details('After'));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, offset);
      expect(tester.takeException(), isNull);

      pending = Completer<Map<String, dynamic>>();
      events.add({'eventType': 'chat.group.changed'});
      await tester.pump();
      pending.completeError(
        const AuthFailure('CHAT_GROUP_ACCESS_DENIED', 'Access denied'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('group-name-row')), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining('Access denied'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await events.close();
    },
  );

  testWidgets(
    'owner rename preserves failed draft then refreshes acknowledged name',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      var name = '原群名';
      var fail = true;
      Map<String, dynamic>? request;
      final repo = GroupChatRepository(
        MessagingRepository(
          account: 'me',
          call: (id, params) async {
            if (id == 'K260913000619') {
              return {
                'groupName': name,
                'ownerAccount': 'me',
                'metadataVersion': 2,
                'members': [],
              };
            }
            if (id == 'K260913000621') {
              return {
                'settings': {'muted': false, 'pinned': false},
              };
            }
            if (id == 'K260913000624') {
              request = params;
              if (fail) throw StateError('保存失败');
              name = params['name'] as String;
              return {'groupName': name, 'metadataVersion': 3, 'changed': true};
            }
            throw StateError(id);
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GroupDetailsPage(groupId: 'group-real', repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('group-name-row')));
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('group-name-input'));
      await tester.enterText(input, '新群名');
      await tester.tap(find.byKey(const ValueKey('group-name-save')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, '新群名');
      expect(find.text('原群名'), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const ValueKey('group-name-save')));
      await tester.pumpAndSettle();
      expect(request, {
        'groupId': 'group-real',
        'name': '新群名',
        'expectedVersion': 2,
      });
      expect(input, findsNothing);
      expect(find.text('新群名'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
      await tester.pumpAndSettle();
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
