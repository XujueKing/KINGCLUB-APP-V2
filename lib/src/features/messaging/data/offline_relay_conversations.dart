import 'chat_history_store.dart';

/// Local display projection; cached server unread counts remain provisional.
/// No network call or permission decision is made here.
Future<List<Map<String, dynamic>>> offlineRelayConversations(
  ChatHistoryStore history,
  List<Map<String, dynamic>> cached, {
  List<Map<String, dynamic>> knownRows = const [],
}) async {
  final rows = [for (final row in cached) Map<String, dynamic>.from(row)];
  final known = {
    for (final row in knownRows)
      if (row['kind'] != 'group')
        row['peer'] as String: Map<String, dynamic>.from(row),
  };
  final seen = rows
      .where((r) => r['kind'] != 'group')
      .map((r) => r['peer'] as String)
      .toSet();
  String? cursor;
  while (true) {
    final members = await history.nearbyConversationMembers(
      afterMember: cursor,
    );
    for (final peer in members) {
      if (!seen.add(peer)) continue;
      rows.add({
        'kind': 'direct',
        'peer': peer,
        'nickname': peer,
        'preview': '',
        'lastSequence': 0,
        'unreadCount': 0,
        'relayUnreadCount': 0,
        'muted': false,
        'pinned': false,
        ...?known[peer],
        'localOnly': true,
      });
    }
    if (members.length < 100) break;
    cursor = members.last;
  }
  final result = <Map<String, dynamic>>[];
  for (final row in rows) {
    if (row['kind'] != 'group') {
      final peer = row['peer'] as String;
      final local = await history.nearbyMemberMessages(
        peer,
        limit: 1,
        forPreview: true,
      );
      if (row['localOnly'] == true && local.isEmpty) continue;
      final count = await history.nearbyUnreadCount(peerAccount: peer);
      final serverCount =
          ((row['unreadCount'] as num).toInt() -
                  ((row['relayUnreadCount'] as num?)?.toInt() ?? 0))
              .clamp(0, 1 << 31);
      row['unreadCount'] = serverCount + count;
      row['relayUnreadCount'] = count;
      if (local.isNotEmpty) {
        final latest = local.single;
        final date = DateTime.fromMillisecondsSinceEpoch(
          latest['created'] as int,
          isUtc: true,
        );
        final previous = DateTime.tryParse(row['messageDate'] as String? ?? '');
        if (previous == null || !date.isBefore(previous)) {
          row['preview'] = latest['text'];
          row['messageDate'] = date.toIso8601String();
        }
      }
    }
    result.add(row);
  }
  sortConversationRows(result);
  return result;
}

/// Sort loaded rows without disturbing the relative order of equal dates.
List<Map<String, dynamic>> mergeConversationRows(
  List<Map<String, dynamic>> existing,
  List<Map<String, dynamic>> incoming,
) {
  String key(Map<String, dynamic> row) => row['kind'] == 'group'
      ? 'group:${row['groupId']}'
      : 'direct:${row['peer']}';
  final keyed = {
    for (final row in [...existing, ...incoming])
      key(row): Map<String, dynamic>.from(row),
  };
  final result = keyed.values.toList();
  sortConversationRows(result);
  return result;
}

void sortConversationRows(List<Map<String, dynamic>> result) {
  final indices = {for (var i = 0; i < result.length; i++) result[i]: i};
  result.sort((a, b) {
    final pinned =
        (b['pinned'] == true ? 1 : 0) - (a['pinned'] == true ? 1 : 0);
    if (pinned != 0) return pinned;
    final aDate =
        DateTime.tryParse(a['messageDate'] as String? ?? '')
            ?.millisecondsSinceEpoch ??
        0;
    final bDate =
        DateTime.tryParse(b['messageDate'] as String? ?? '')
            ?.millisecondsSinceEpoch ??
        0;
    final date = bDate.compareTo(aDate);
    return date == 0 ? indices[a]!.compareTo(indices[b]!) : date;
  });
}
