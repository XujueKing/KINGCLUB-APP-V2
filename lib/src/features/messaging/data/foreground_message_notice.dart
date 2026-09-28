typedef ForegroundMessageNotice = ({
  String target,
  bool group,
  String name,
  int unread,
});

/// Resolve hints against authorized, read-projected conversation state. Events
/// carry IDs only; they must not invent a sender, body, or navigation target.
class ForegroundMessageNoticeResolver {
  final _seen = <String, int>{};
  int _generation = 0;
  void clear() {
    _generation++;
    _seen.clear();
  }

  /// Reconcile a reconnect against authorized unread state, sharing the same
  /// sequence watermark as live events so reconnects cannot repeat a notice.
  Future<List<ForegroundMessageNotice>> reconcile({
    required String account,
    required Future<Map<String, dynamic>> Function(int offset) page,
    required bool Function() valid,
    Future<bool> Function(ForegroundMessageNotice notice)? deliver,
  }) async {
    final pending = <Map>[];
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    for (var offset = 0; valid() && DateTime.now().isBefore(deadline);) {
      final result = await page(offset);
      if (!valid()) return [];
      final rows = result['items'];
      if (rows is! List || rows.isEmpty) break;
      pending.addAll(rows.whereType<Map>());
      if (result['hasMore'] != true) break;
      offset += rows.length;
    }
    if (!valid()) return [];
    final notices = <ForegroundMessageNotice>[];
    for (final row in pending) {
      if (!valid()) break;
      final notice = await _deliver(row, account, valid, deliver);
      if (notice != null) notices.add(notice);
    }
    return notices;
  }

  Future<ForegroundMessageNotice?> _deliver(
    Map row,
    String account,
    bool Function() valid,
    Future<bool> Function(ForegroundMessageNotice notice)? deliver,
  ) async {
    final generation = _generation;
    final notice = _consume(row, account, commit: deliver == null);
    if (notice == null || deliver == null) return notice;
    // Failed/late platform submissions must remain eligible on reconnect.
    if (!await deliver(notice) || !valid() || generation != _generation) {
      return null;
    }
    _consume(row, account);
    return notice;
  }

  ForegroundMessageNotice? _consume(
    Map row,
    String account, {
    bool commit = true,
  }) {
    final id = row['conversationId'];
    final group = row['kind'] == 'group';
    if (id is! String || id.isEmpty) return null;
    final sequence = (row['lastSequence'] as num?)?.toInt() ?? 0;
    final key = '$account:$group:$id';
    if (sequence <= (_seen[key] ?? 0)) return null;
    if (commit) _seen[key] = sequence;
    // One sequence per conversation until account reset, rather than evicting
    // early pages and re-alerting them whenever a large inbox reconnects.
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
      unread: (row['unreadCount'] as num).toInt(),
      name: (row['remark'] as String?)?.isNotEmpty == true
          ? row['remark'] as String
          : row['nickname'] as String? ?? '聊天',
    );
  }

  Future<ForegroundMessageNotice?> resolve({
    required Map<String, dynamic> event,
    required String account,
    required Future<Map<String, dynamic>> Function(int offset) page,
    required bool Function() valid,
    Future<bool> Function(ForegroundMessageNotice notice)? deliver,
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
        return _deliver(row, account, valid, deliver);
      }
      if (result['hasMore'] != true) return null;
      offset += rows.length;
    }
    return null;
  }
}
