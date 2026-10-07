import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/data/membership_review_refresh.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/system_notices_controller.dart';
import 'package:kingclub/src/features/messaging/data/system_notices_repository.dart';

const pending = AuthLoginResult(
  isNewMembership: false,
  membershipStatus: 'active',
  registrationStatus: 'pending_review',
  isRealSession: true,
);
const approved = AuthLoginResult(
  isNewMembership: false,
  membershipStatus: 'active',
  registrationStatus: 'approved',
  isRealSession: true,
);
Map<String, dynamic> session(String id) => {
  'sessionId': id,
  'account': {'userAccount': 'synthetic-$id'},
};

void main() {
  test('hint refreshes once, only a verified approval shows the banner, and subsequent reconnects do not repeat it', () async {
    AuthLoginResult member = pending;
    var calls = 0;
    final response = Completer<AuthLoginResult>();
    final shown = <String>[];
    final runtime = MembershipReviewRefresh(
      readMember: () => member,
      readSession: () async => session('one'),
      refreshMembership: () async {
        calls++;
        member = await response.future;
        return member;
      },
      onApproved: shown.add,
    );
    final first = runtime.notify();
    await Future<void>.delayed(Duration.zero);
    await runtime.notify();
    expect(calls, 1);
    expect(shown, isEmpty);
    response.complete(approved);
    await first;
    expect(shown, ['one']);
    await runtime.notify();
    expect(calls, 1);
    expect(shown, ['one']);
    runtime.close();
  });

  test('outage and unchanged pending status never grant entry; a reconnect can retry', () async {
    var calls = 0;
    var shown = 0;
    final runtime = MembershipReviewRefresh(
      readMember: () => pending,
      readSession: () async => session('one'),
      refreshMembership: () async {
        if (++calls == 1) throw Exception('offline');
        return pending;
      },
      onApproved: (_) => shown++,
    );
    await runtime.notify();
    await runtime.notify();
    expect(calls, 2);
    expect(shown, 0);
    runtime.close();
  });

  for (final close in [false, true]) {
    test(
      'discard approval after ${close ? 'dispose' : 'account switch'}',
      () async {
        var member = pending;
        var current = 'one';
        final result = Completer<AuthLoginResult>();
        var shown = 0;
        final runtime = MembershipReviewRefresh(
          readMember: () => member,
          readSession: () async => session(current),
          refreshMembership: () => result.future,
          onApproved: (_) => shown++,
        );
        final request = runtime.notify();
        await Future<void>.delayed(Duration.zero);
        if (close) {
          runtime.close();
        } else {
          current = 'two';
        }
        member = approved;
        result.complete(approved);
        await request;
        expect(shown, 0);
        runtime.close();
      },
    );
  }

  test('persistent membership card drives unread and one arrival; opening it clears unread, history is silent', () async {
    var rows = <Map<String, dynamic>>[];
    final arrivals = <SystemNotice>[];
    final subscription = SystemNoticesController.arrivals.listen(
      (e) => arrivals.add(e.notice),
    );
    addTearDown(subscription.cancel);
    SystemNoticesController makeInbox() => SystemNoticesController(
      SystemNoticesRepository(
        readSession: () async => {
          ...session('one'),
          'apiKeyId': 'key',
          'apiKey': 'secret',
        },
        request: (id, params, s) async {
          expect(params['membershipNotices'], 1);
          if (id == 'K261002001961')
            rows = [
              for (final row in rows) {...row, 'read': true},
            ];
          return {
            'result': {
              'notices': rows,
              'nextBeforeNotice': null,
              'unreadCount': rows.where((r) => r['read'] == false).length,
              'latest': rows.isEmpty ? null : rows.first,
              'highWaterSequence': rows.isEmpty ? null : '1',
            },
          };
        },
      ),
    );
    final inbox = makeInbox();
    addTearDown(inbox.dispose);
    await inbox.refresh();
    rows = [
      {
        'noticeRef': 'a' * 64,
        'kind': 'membership_approved',
        'occurredAt': '2030-01-01T00:00:00.000Z',
        'read': false,
        'amountCents': null,
        'target': null,
        'details': [
          {
            'label': 'status',
            'value': {
              'zh-CN': '审核通过',
              'en': 'Approved',
              'zh-TW': '審核通過',
              'th': 'อนุมัติแล้ว',
            },
          },
        ],
      },
    ];
    await inbox.refresh();
    await inbox.refresh();
    expect(inbox.summary.unreadCount, 1);
    expect(arrivals.length, 1);
    final restored = makeInbox();
    addTearDown(restored.dispose);
    await restored.refresh();
    expect(restored.summary.unreadCount, 1);
    expect(arrivals.length, 1);
    await inbox.markRead(id: 'a' * 64);
    expect(inbox.summary.unreadCount, 0);
    expect(inbox.notices.single.read, true);
  });
}
