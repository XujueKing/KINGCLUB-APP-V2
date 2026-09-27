typedef ForegroundMessageNotice = ({String target, bool group, String name});

/// Resolve hints against authorized, read-projected conversation state. Events
/// carry IDs only; they must not invent a sender, body, or navigation target.
class ForegroundMessageNoticeResolver {
  final _seen = <String, int>{};
  void clear() => _seen.clear();

  Future<ForegroundMessageNotice?> resolve({
    required Map<String, dynamic> event,
    required String account,
    required Future<Map<String, dynamic>> Function(int offset) page,
    required bool Function() valid,
  }) async {
    final group = event['eventType'] == 'chat.group.message';
    if (!group && event['eventType'] != 'chat.changed') return null;
    final data = event['data'];
    if (data is! Map) return null;
    final id = data[group ? 'groupId' : 'conversationId'];
    if (id is! String || id.isEmpty) return null;
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    for (var offset = 0; valid() && DateTime.now().isBefore(deadline);) {
      final result = await page(offset);
      if (!valid()) return null;
      final rows = result['items'];
      if (rows is! List || rows.isEmpty) return null;
      for (final row in rows.whereType<Map>()) {
        if (row['conversationId'] != id || (row['kind'] == 'group') != group) {
          continue;
        }
        final sequence = (row['lastSequence'] as num?)?.toInt() ?? 0;
        final key = '$account:$group:$id';
        if (sequence <= (_seen[key] ?? 0)) return null;
        _seen[key] = sequence;
        if (_seen.length > 256) _seen.remove(_seen.keys.first);
        if (row['muted'] == true ||
            row['sender'] == account ||
            (row['unreadCount'] as num? ?? 0) <= 0) {
          return null;
        }
        final target = row[group ? 'groupId' : 'peer'];
        if (target is! String || target.isEmpty) return null;
        return (
          target: target,
          group: group,
          name: (row['remark'] as String?)?.isNotEmpty == true
              ? row['remark'] as String
              : row['nickname'] as String? ?? '聊天',
        );
      }
      if (result['hasMore'] != true) return null;
      offset += rows.length;
    }
    return null;
  }
}
