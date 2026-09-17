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
}
