import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/pending_conversation_rows.dart';

void main() {
  test('pending first conversations isolate accounts, deduplicate and choose latest', () {
    final rows = pendingConversationRows('me', [], [
      {
        'sender': 'me',
        'recipient': 'peer',
        'text': 'old',
        'createdDate': '2026-09-17T10:00:00Z',
      },
      {
        'sender': 'me',
        'recipient': 'peer',
        'text': 'latest',
        'createdDate': '2026-09-17T10:01:00Z',
      },
      {'sender': 'other', 'recipient': 'hidden', 'text': 'private'},
      {'sender': 'me', 'groupId': 'peer', 'messageType': 'voice'},
    ]);
    expect(rows, hasLength(2));
    expect(rows.first['preview'], contains('latest'));
    expect(rows.first['unreadCount'], 0);
    expect(rows.last['kind'], 'group');
    expect(rows.last['preview'], isNot(contains('private')));
    final merged = pendingConversationRows(
      'me',
      [
        {
          'kind': 'direct',
          'peer': 'peer',
          'nickname': 'Friend',
          'unreadCount': 2,
        },
      ],
      [
        {'sender': 'me', 'recipient': 'peer', 'text': 'queued'},
      ],
    );
    expect(merged, hasLength(1));
    expect(merged.single['unreadCount'], 2);
    expect(merged.single['nickname'], 'Friend');
  });
  for (final group in [false, true]) {
    test(
      'existing conversation projects newest pending content group=$group',
      () {
        final targetField = group ? 'groupId' : 'peer';
        final outgoingField = group ? 'groupId' : 'recipient';
        final confirmed = <String, dynamic>{
          'kind': group ? 'group' : 'direct',
          targetField: 'target',
          'nickname': 'Kept name',
          'remark': 'Kept remark',
          'unreadCount': 3,
          'muted': true,
          'pinned': true,
          'preview': 'confirmed',
          'messageDate': '2026-09-18T01:00:00Z',
        };
        Map<String, dynamic> pending(
          String text,
          String date, {
          String status = 'queued',
        }) => {
          'sender': 'me',
          outgoingField: 'target',
          'text': text,
          'createdDate': date,
          'status': status,
        };
        final rows = pendingConversationRows(
          'me',
          [confirmed],
          [
            pending('old', '2026-09-17T01:00:00Z'),
            pending('new', '2026-09-18T01:02:00Z', status: 'failed'),
            pending('middle', '2026-09-18T01:01:00Z'),
          ],
        );
        expect(rows.single['preview'], '[发送失败] new');
        for (final field in [
          'nickname',
          'remark',
          'unreadCount',
          'muted',
          'pinned',
        ]) {
          expect(rows.single[field], confirmed[field]);
        }
        expect(rows.single['_pendingOnly'], isNot(true));
        expect(confirmed['preview'], 'confirmed');
        expect(
          pendingConversationRows('me', [confirmed], []).single,
          confirmed,
        );
        expect(
          pendingConversationRows(
            'me',
            [confirmed],
            [
              pending('stale', '2026-09-17T01:00:00Z'),
              pending('same time', '2026-09-18T01:00:00Z'),
            ],
          ).single,
          confirmed,
        );
      },
    );
  }
  test('pending activity sorts existing conversations without changing pin metadata', () {
    final rows = pendingConversationRows(
      'me',
      [
        {'peer': 'a', 'messageDate': '2026-09-18T02:00:00Z', 'pinned': true},
        {'peer': 'b', 'messageDate': '2026-09-18T01:00:00Z', 'unreadCount': 0},
      ],
      [
        {
          'sender': 'me',
          'recipient': 'b',
          'messageType': 'video',
          'createdDate': '2026-09-18T03:00:00Z',
        },
      ],
    );
    expect(rows.first['peer'], 'b');
    expect(rows.first['preview'], '[待发送] [视频]');
    expect(rows.last['pinned'], true);
  });
}
