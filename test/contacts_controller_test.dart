import 'package:flutter/material.dart';
import 'package:kingclub/src/features/contacts/presentation/contacts_page.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/data/contacts_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

Map<String, dynamic> contact(String account) => {
  'peer': account,
  'nickname': 'Name $account',
  'remark': '',
  'gender': null,
  'bio': '',
};
Map<String, dynamic> page(
  List<Map<String, dynamic>> rows, {
  bool more = false,
}) => {'items': rows, 'hasMore': more};

void main() {
  test('session reset discards an in-flight badge response', () async {
    final response = Completer<Map<String, dynamic>>();
    final controller = ContactsController(
      MessagingRepository(account: 'me', call: (_, _) => response.future),
    );
    final reading = controller.refreshRequests();
    controller.invalidate();
    response.complete(
      page([
        {'requestId': 'private', 'recipient': 'me', 'requestStatus': 'pending'},
      ]),
    );
    await reading;
    expect(controller.pendingRequests, 0);
    controller.dispose();
  });

  testWidgets('new friends shows a real incoming count even without contacts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MessagingRepository(
      account: 'me',
      call: (id, _) async {
        if (id == 'K260913000611')
          return page([
            {
              'requestId': 'actual-request',
              'recipient': 'me',
              'requestStatus': 'pending',
            },
          ]);
        if (id == 'K260913000615') return {'version': 0, 'groups': []};
        return page([]);
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContactsPage(
            active: true,
            realData: true,
            repository: repository,
            onIntent: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('新的朋友'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('还没有好友'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'relationship notification during refresh drains one additional snapshot',
    () async {
      final old = Completer<Map<String, dynamic>>();
      var reads = 0;
      final controller = ContactsController(
        MessagingRepository(
          account: 'me',
          call: (_, _) async {
            reads++;
            return reads == 1 ? old.future : page([contact('new-friend')]);
          },
        ),
      );
      final refreshing = controller.refresh();
      controller.refresh(afterCurrent: true);
      controller.refresh(afterCurrent: true);
      old.complete(page([contact('old-friend')]));
      await refreshing;
      expect(reads, 2);
      expect(controller.contacts.single.account, 'new-friend');
      controller.dispose();
    },
  );

  test('incoming pending badge deduplicates pages and excludes outgoing or resolved', () async {
    final offsets = <int>[];
    Map<String, dynamic> request(String id, String recipient, String status) =>
        {'requestId': id, 'recipient': recipient, 'requestStatus': status};
    final controller = ContactsController(
      MessagingRepository(
        account: 'me',
        call: (id, params) async {
          expect(id, 'K260913000611');
          final offset = params['offset'] as int;
          offsets.add(offset);
          return offset == 0
              ? page([
                  request('incoming', 'me', 'pending'),
                  request('outgoing', 'peer', 'pending'),
                  request('accepted', 'me', 'accepted'),
                  request('rejected', 'me', 'rejected'),
                ], more: true)
              : page([
                  request('incoming', 'me', 'pending'),
                  request('second', 'me', 'pending'),
                ]);
        },
      ),
    );
    await controller.refreshRequests();
    expect(controller.pendingRequests, 2);
    expect(offsets, [0, 4]);
    controller.invalidate();
    expect(controller.pendingRequests, 0);
    controller.dispose();
  });

  test(
    'badge drops obsolete responses and clears on session invalidation',
    () async {
      final late = Completer<Map<String, dynamic>>();
      var reads = 0;
      final controller = ContactsController(
        MessagingRepository(
          account: 'me',
          call: (_, _) async {
            reads++;
            if (reads == 1) return late.future;
            return page([]);
          },
        ),
      );
      final oldRead = controller.refreshRequests();
      await controller.refreshRequests();
      late.complete(
        page([
          {'requestId': 'old', 'recipient': 'me', 'requestStatus': 'pending'},
        ]),
      );
      await oldRead;
      expect(controller.pendingRequests, 0);
      controller.dispose();
    },
  );

  testWidgets(
    'real contacts page emits the actual account without demo contacts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      ContactRouteIntent? selected;
      final repository = MessagingRepository(
        account: 'me',
        call: (_, _) async => page([
          {...contact('actual-account'), 'nickname': 'Actual friend'},
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactsPage(
              active: true,
              realData: true,
              repository: repository,
              onIntent: (intent) => selected = intent,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Actual friend'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      expect(find.text('卡座搭子'), findsNothing);
      await tester.tap(find.text('Actual friend'));
      expect(selected?.targetRef, 'actual-account');
      expect(selected?.kind, ContactIntentKind.userProfile);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'loads all pages atomically and deduplicates account identities',
    () async {
      final second = Completer<Map<String, dynamic>>();
      final offsets = <int>[];
      final controller = ContactsController(
        MessagingRepository(
          account: 'me',
          call: (id, params) async {
            expect(id, 'K260913000608');
            offsets.add(params['offset'] as int);
            return params['offset'] == 0
                ? page([contact('a')], more: true)
                : second.future;
          },
        ),
      );
      final refresh = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(controller.contacts, isEmpty);
      expect(identical(controller.refresh(), refresh), isTrue);
      second.complete(
        page([
          contact('a'),
          {...contact('b'), 'remark': 'Buddy'},
        ]),
      );
      await refresh;
      expect(offsets, [0, 1]);
      expect(controller.contacts.map((c) => c.account), ['a', 'b']);
      expect(controller.search('buddy').single.account, 'b');
      expect(controller.contacts.first.remark, isNull);
      controller.dispose();
    },
  );

  test('failed refresh preserves last complete snapshot; success removes ex-friends', () async {
    var phase = 0;
    final controller = ContactsController(
      MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (phase == 0) return page([contact('a'), contact('b')]);
          if (phase == 1) {
            if (params['offset'] == 0) return page([contact('c')], more: true);
            throw StateError('network offline');
          }
          return page([contact('b')]);
        },
      ),
    );
    await controller.refresh();
    phase = 1;
    await controller.refresh();
    expect(controller.contacts.map((c) => c.account), ['a', 'b']);
    expect(controller.error, isNotNull);
    phase = 2;
    await controller.refresh();
    expect(controller.contacts.single.account, 'b');
    expect(controller.error, isNull);
    controller.dispose();
  });

  test('session invalidation rejects late account data', () async {
    final response = Completer<Map<String, dynamic>>();
    final controller = ContactsController(
      MessagingRepository(
        account: 'old-account',
        call: (_, _) => response.future,
      ),
    );
    final refresh = controller.refresh();
    controller.invalidate();
    response.complete(page([contact('private-friend')]));
    await refresh;
    expect(controller.contacts, isEmpty);
    expect(controller.hasSnapshot, isFalse);
    controller.dispose();
  });

  test('malformed empty continuation stops instead of looping', () async {
    var calls = 0;
    final controller = ContactsController(
      MessagingRepository(
        account: 'me',
        call: (_, _) async {
          calls++;
          return page([], more: true);
        },
      ),
    );
    await controller.refresh();
    expect(calls, 1);
    expect(controller.hasSnapshot, isFalse);
    expect(controller.error, isNotNull);
    controller.dispose();
  });
}
