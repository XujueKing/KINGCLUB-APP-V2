import 'dart:async';

import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/public_member_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

void main() {
  testWidgets('profile tabs fit large system text on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 713));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MessagingRepository(
      account: 'me',
      call: (id, _) async => id == 'K260913000614'
          ? {'items': [], 'nextOffset': null}
          : {
              'peer': 'peer',
              'memberId': 'TEST001',
              'nickname': 'Friend',
              'bio': '',
              'details': {},
              'friends': true,
              'following': true,
              'contentVisible': true,
            },
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.35)),
          child: child!,
        ),
        home: PublicMemberPage(account: 'peer', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['作品', '动态', '相册']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(
        paragraph.computeMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(paragraph.size.width + 0.1),
      );
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(find.text('暂无相册内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'late content response cannot restore a newly restricted profile',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      final content = Completer<Map<String, dynamic>>();
      var visible = true, contentReads = 0;
      final repository = MessagingRepository(
        account: 'me',
        call: (id, _) async {
          if (id == 'K260913000614') {
            contentReads++;
            return content.future;
          }
          return {
            'peer': 'peer',
            'memberId': 'TEST001',
            'nickname': 'Friend',
            'bio': '',
            'details': {},
            'friends': true,
            'following': true,
            'contentVisible': visible,
          };
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
      expect(contentReads, 1);
      visible = false;
      events.add({'eventType': 'chat.settings.changed'});
      await tester.pumpAndSettle();
      expect(find.text('暂时无法查看'), findsOneWidget);
      content.complete({
        'items': [
          {'ref': 'old-private-work', 'media': null},
        ],
        'nextOffset': null,
      });
      await tester.pumpAndSettle();
      expect(find.byType(SliverGrid), findsNothing);
      expect(find.text('暂时无法查看'), findsOneWidget);
      expect(find.text('私信'), findsOneWidget);
      expect(contentReads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await events.close();
    },
  );
  testWidgets('accepted QR friend request refreshes open profile relation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final events = StreamController<Map<String, dynamic>>.broadcast();
    var friends = false, reads = 0;
    final repo = MessagingRepository(
      account: 'me',
      call: (id, _) async {
        if (id == 'K260913000614') return {'items': [], 'nextOffset': null};
        reads++;
        return {
          'peer': 'peer',
          'memberId': 'TEST001',
          'nickname': 'Friend',
          'bio': '',
          'details': {},
          'following': friends,
          'friends': friends,
          'contentVisible': false,
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PublicMemberPage(
          account: 'peer',
          repository: repo,
          events: events.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('互相关注'), findsNothing);
    friends = true;
    events.add({'eventType': 'chat.friend-request.changed'});
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('互相关注'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await events.close();
  });
  testWidgets(
    'permission changes hide stale profile immediately and logout rejects refresh',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final events = StreamController<Map<String, dynamic>>.broadcast();
      final response = Completer<Map<String, dynamic>>();
      var calls = 0;
      final profile = <String, dynamic>{
        'peer': 'peer',
        'memberId': 'TEST001',
        'nickname': 'Private fixture',
        'bio': '',
        'details': {},
        'contentVisible': true,
      };
      final repository = MessagingRepository(
        account: 'me',
        call: (id, _) async {
          if (id == 'K260913000614') return {'items': [], 'nextOffset': null};
          calls++;
          return calls == 1 ? profile : response.future;
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
      expect(find.text('Private fixture'), findsOneWidget);
      events.add({'eventType': 'chat.settings.changed'});
      await tester.pump(); // Deliver the asynchronous stream event.
      await tester.pump(); // Render the invalidated state before HTTP returns.
      expect(find.text('Private fixture'), findsNothing);
      expect(calls, 2);
      SecureSessionStore.changes.add(null);
      await tester.pump();
      response.complete({...profile, 'contentVisible': false});
      await tester.pumpAndSettle();
      expect(find.text('Private fixture'), findsNothing);
      events.add({'eventType': 'connection.ready'});
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
      await events.close();
    },
  );

  testWidgets('following button requires explicit unfollow confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final mutations = <Map<String, dynamic>>[];
    final repository = MessagingRepository(
      account: 'me',
      call: (id, params) async {
        if (params.containsKey('action')) {
          mutations.add(params);
          return {};
        }
        if (id == 'K260913000614') return {'items': [], 'nextOffset': null};
        return {
          'peer': 'peer',
          'memberId': 'TEST001',
          'nickname': 'Friend',
          'bio': '',
          'details': {},
          'following': true,
          'friends': true,
          'contentVisible': false,
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PublicMemberPage(account: 'peer', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('互相关注'));
    await tester.pumpAndSettle();
    expect(mutations, isEmpty);
    await tester.tap(find.text('保留关注'));
    await tester.pumpAndSettle();
    expect(mutations, isEmpty);
    await tester.tap(find.text('互相关注'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消关注'));
    await tester.pumpAndSettle();
    expect(mutations.single['action'], 'unfollow');
  });

  testWidgets('real profile retains chat when contents are restricted', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final calls = <String>[];
    final repo = MessagingRepository(
      account: 'me',
      call: (id, params) async {
        calls.add(id);
        expect(params['peer'], 'peer');
        if (id == 'K260913000604') {
          return {
            'conversationId': 'pair',
            'messages': [],
            'hasMore': false,
            'settings': {},
            'sendPermission': {'allowed': true},
            'peerReadSequence': 0,
          };
        }
        return {
          'peer': 'peer',
          'memberId': 'TEST001',
          'nickname': 'Test friend',
          'bio': 'Public bio',
          'age': 30,
          'details': {},
          'friends': true,
          'following': true,
          'contentVisible': false,
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PublicMemberPage(account: 'peer', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test friend'), findsOneWidget);
    expect(find.text('作品'), findsOneWidget);
    expect(find.text('动态'), findsOneWidget);
    expect(find.text('相册'), findsOneWidget);
    expect(find.text('暂时无法查看'), findsOneWidget);
    expect(find.text('KING官方'), findsNothing);
    await tester.tap(find.text('私信'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DirectChatPage>(find.byType(DirectChatPage)).peerAccount,
      'peer',
    );
    expect(calls.first, 'K260913000612');
    expect(tester.takeException(), isNull);
  });
}
