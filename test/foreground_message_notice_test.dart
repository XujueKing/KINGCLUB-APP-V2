import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/foreground_message_notice.dart';
import 'package:kingclub/src/features/messaging/presentation/foreground_message_banner.dart';

void main() {
  const event = {
    'eventType': 'chat.changed',
    'data': {'conversationId': 'pair'},
  };
  Map<String, dynamic> row() => {
    'conversationId': 'pair',
    'kind': 'direct',
    'peer': 'bob',
    'sender': 'bob',
    'lastSequence': 3,
    'unreadCount': 1,
    'muted': false,
    'nickname': '好友',
  };
  Future<ForegroundMessageNotice?> resolve(
    ForegroundMessageNoticeResolver r,
    Map<String, dynamic> item, {
    String account = 'alice',
  }) => r.resolve(
    event: event,
    account: account,
    valid: () => true,
    page: (_) async => {
      'items': [item],
      'hasMore': false,
    },
  );
  test(
    'resolves authorized target and deduplicates sequence, account isolated',
    () async {
      final r = ForegroundMessageNoticeResolver();
      expect(await resolve(r, row()), (
        target: 'bob',
        group: false,
        name: '好友',
        unread: 1,
      ));
      expect(await resolve(r, row()), isNull);
      expect(await resolve(r, row(), account: 'carol'), isNotNull);
    },
  );
  test('muted, read and self-sent events do not notify', () async {
    for (final change in [
      {'muted': true},
      {'unreadCount': 0},
      {'sender': 'alice'},
    ]) {
      expect(
        await resolve(ForegroundMessageNoticeResolver(), {...row(), ...change}),
        isNull,
      );
    }
  });
  test(
    'notification replacement carries authoritative unread count, not one',
    () async {
      final r = ForegroundMessageNoticeResolver();
      final first = await resolve(r, {...row(), 'unreadCount': 7});
      expect(first?.unread, 7);
      final next = await resolve(r, {
        ...row(),
        'lastSequence': 4,
        'unreadCount': 3,
      });
      expect(next?.unread, 3);
    },
  );
  test(
    'finds group after pinned page and ignores non-message events',
    () async {
      final offsets = <int>[];
      final r = ForegroundMessageNoticeResolver();
      final notice = await r.resolve(
        event: {
          'eventType': 'chat.group.message',
          'data': {'groupId': 'group'},
        },
        account: 'alice',
        valid: () => true,
        page: (offset) async {
          offsets.add(offset);
          return offset == 0
              ? {
                  'items': [row()],
                  'hasMore': true,
                }
              : {
                  'items': [
                    {
                      ...row(),
                      'conversationId': 'group',
                      'groupId': 'group',
                      'kind': 'group',
                    },
                  ],
                  'hasMore': false,
                };
        },
      );
      expect(offsets, [0, 1]);
      expect(notice?.target, 'group');
      expect(notice?.group, true);
      expect(
        await r.resolve(
          event: {'eventType': 'chat.read.changed'},
          account: 'alice',
          valid: () => true,
          page: (_) async => throw StateError('must not fetch'),
        ),
        isNull,
      );
    },
  );
  test(
    'account/background invalidation during lookup drops late result',
    () async {
      final reply = Completer<Map<String, dynamic>>();
      var valid = true;
      final pending = ForegroundMessageNoticeResolver().resolve(
        event: event,
        account: 'alice',
        valid: () => valid,
        page: (_) => reply.future,
      );
      valid = false;
      reply.complete({
        'items': [row()],
      });
      expect(await pending, isNull);
    },
  );
  test(
    'reconnect and live events share watermarks across a large paged inbox',
    () async {
      final r = ForegroundMessageNoticeResolver();
      Future<Map<String, dynamic>> page(int offset) async => {
        'items': List.generate(
          100,
          (i) => {
            ...row(),
            'conversationId': 'pair${offset + i}',
            'peer': 'peer${offset + i}',
          },
        ),
        'hasMore': offset < 200,
      };
      expect(
        await r.reconcile(account: 'alice', page: page, valid: () => true),
        hasLength(300),
      );
      expect(
        await r.reconcile(account: 'alice', page: page, valid: () => true),
        isEmpty,
      );
      expect(
        await r.resolve(
          event: {
            'eventType': 'chat.changed',
            'data': {'conversationId': 'pair0'},
          },
          account: 'alice',
          page: page,
          valid: () => true,
        ),
        isNull,
      );
    },
  );
  test(
    'reconnect filters muted/read/self rows and resolves group targets',
    () async {
      final r = ForegroundMessageNoticeResolver();
      final result = await r.reconcile(
        account: 'alice',
        valid: () => true,
        page: (_) async => {
          'items': [
            {...row(), 'conversationId': 'muted', 'muted': true},
            {...row(), 'conversationId': 'read', 'unreadCount': 0},
            {...row(), 'conversationId': 'self', 'sender': 'alice'},
            {
              ...row(),
              'conversationId': 'group',
              'kind': 'group',
              'groupId': 'team',
            },
          ],
        },
      );
      expect(result.single.target, 'team');
      expect(result.single.group, true);
    },
  );
  test(
    'failed or invalidated reconciliation does not consume earlier pages',
    () async {
      final r = ForegroundMessageNoticeResolver();
      await expectLater(
        r.reconcile(
          account: 'alice',
          valid: () => true,
          page: (offset) async {
            if (offset > 0) throw StateError('network lost');
            return {
              'items': [row()],
              'hasMore': true,
            };
          },
        ),
        throwsStateError,
      );
      expect(await resolve(r, row()), isNotNull);
      r.clear();
      var valid = true;
      expect(
        await r.reconcile(
          account: 'alice',
          valid: () => valid,
          page: (_) async {
            valid = false;
            return {
              'items': [row()],
            };
          },
        ),
        isEmpty,
      );
      expect(await resolve(r, row()), isNotNull);
    },
  );
  testWidgets(
    'legacy banner opens, dismisses and hidden overlay does not intercept',
    (tester) async {
      var opens = 0, closes = 0;
      Widget view(bool visible) => MaterialApp(
        home: Scaffold(
          body: ForegroundMessageBanner(
            visible: visible,
            onTap: () => opens++,
            onDismiss: () => closes++,
          ),
        ),
      );
      await tester.pumpWidget(view(true));
      expect(find.text('您收到一条新消息'), findsOneWidget);
      await tester.tap(find.text('您收到一条新消息'));
      expect(opens, 1);
      expect(find.text('现在'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      await tester.fling(
        find.byKey(const ValueKey('legacy-message-banner-card')),
        const Offset(0, -100),
        500,
      );
      expect(closes, 1);
      await tester.pumpWidget(view(false));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .descendant(
                    of: find.byType(ForegroundMessageBanner),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
