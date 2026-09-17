import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/public_member_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

final profile = <String, dynamic>{
  'nickname': 'Fixture',
  'memberId': 'TEST',
  'bio': '',
  'details': {},
  'contentVisible': true,
};
Map<String, dynamic> item(String ref) => {
  'ref': ref,
  'caption': ref,
  'createdAt': '2026-09-13T00:00:00Z',
  'media': null,
};
void main() {
  testWidgets('own profile uses own snapshot and never creates a self pair', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final calls = <String>[];
    final categories = <String>[];
    final repository = MessagingRepository(
      account: 'me',
      call: (id, params) async {
        calls.add(id);
        if (id == 'K260913000612') throw StateError('self pair rejected');
        if (id == 'K260912000501') {
          expect(params, isEmpty);
          return {...profile, 'nickname': 'My actual name'}
            ..remove('contentVisible');
        }
        if (id == 'K260913000614') {
          expect(params['peer'], 'me');
          categories.add(params['category'] as String);
          return {
            'items': [item('Own published content')],
            'nextOffset': null,
          };
        }
        throw StateError('unexpected API $id');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PublicMemberPage(
          account: 'me',
          repository: repository,
          events: const Stream.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My actual name'), findsOneWidget);
    expect(calls, ['K260912000501', 'K260913000614']);
    expect(categories, ['work']);
    final more = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.more_horiz),
    );
    expect(more.onPressed, isNull);
    expect(find.text('发消息'), findsNothing);
    await tester.tap(find.text('动态'));
    await tester.pumpAndSettle();
    expect(find.text('Own published content'), findsOneWidget);
    expect(categories, ['work', 'post']);
    expect(calls, isNot(contains('K260913000612')));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'category changes reject a late response and privacy rejects stale pages',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final work = Completer<Map<String, dynamic>>();
      final post = Completer<Map<String, dynamic>>();
      final events = StreamController<Map<String, dynamic>>.broadcast();
      var restricted = false;
      final requests = <String>[];
      final repository = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000612') {
            return {...profile, 'contentVisible': !restricted};
          }
          requests.add(params['category'] as String);
          if (params['category'] == 'work') return work.future;
          return post.future;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PublicMemberPage(
            account: 'peer',
            repository: repository,
            events: events.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('动态'));
      await tester.pump();
      work.complete({
        'items': [item('Late work')],
        'nextOffset': null,
      });
      await tester.pumpAndSettle();
      expect(find.text('Late work'), findsNothing);
      expect(requests, ['work', 'post']);
      restricted = true;
      events.add({'eventType': 'chat.settings.changed'});
      await tester.pumpAndSettle();
      post.complete({
        'items': [item('Restricted post')],
        'nextOffset': null,
      });
      await tester.pumpAndSettle();
      expect(find.text('Restricted post'), findsNothing);
      expect(find.text('暂时无法查看'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await events.close();
    },
  );
  testWidgets(
    'timeline uses real captions, paginates and shows a real album empty state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final offsets = <int>[];
      final repository = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          if (id == 'K260913000612') return profile;
          if (params['category'] != 'post') {
            return {'items': [], 'nextOffset': null};
          }
          offsets.add(params['offset'] as int);
          return params['offset'] == 0
              ? {
                  'items': [item('First real post')],
                  'nextOffset': 30,
                }
              : {
                  'items': [item('First real post'), item('Second real post')],
                  'nextOffset': null,
                };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PublicMemberPage(account: 'peer', repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂无作品'), findsOneWidget);
      await tester.tap(find.text('动态'));
      await tester.pumpAndSettle();
      expect(find.text('First real post'), findsOneWidget);
      await tester.ensureVisible(find.text('加载更多'));
      await tester.tap(find.text('加载更多'));
      await tester.pumpAndSettle();
      expect(find.text('First real post'), findsOneWidget);
      expect(find.text('Second real post'), findsOneWidget);
      expect(offsets, [0, 30]);
      await tester.ensureVisible(find.text('相册'));
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();
      expect(find.text('暂无相册内容'), findsOneWidget);
      expect(find.text('Second real post'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
