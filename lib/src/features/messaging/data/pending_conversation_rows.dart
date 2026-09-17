/// Pending content updates existing previews and keeps new conversations reachable.
/// These are display-only rows, never server pagination or unread-count inputs.
List<Map<String, dynamic>> pendingConversationRows(
  String account,
  List<Map<String, dynamic>> existing,
  List<Map<String, dynamic>> pending,
) {
  String key(Map<String, dynamic> row) => row['kind'] == 'group'
      ? 'group:${row['groupId']}'
      : 'peer:${row['peer']}';
  final known = {for (final row in existing) key(row): row};
  final latest = <String, Map<String, dynamic>>{};
  for (final message in pending) {
    if (message['sender'] != account) continue;
    final group = message['groupId'] is String;
    final target = message[group ? 'groupId' : 'recipient'];
    if (target is! String || target.isEmpty) continue;
    final identity = '${group ? 'group' : 'peer'}:$target';
    final confirmed = known[identity];
    final confirmedDate = DateTime.tryParse('${confirmed?['messageDate']}');
    final pendingDate = DateTime.tryParse('${message['createdDate']}');
    if (confirmedDate != null &&
        (pendingDate == null || !pendingDate.isAfter(confirmedDate))) {
      continue;
    }
    final date = DateTime.tryParse('${message['createdDate']}');
    final old = latest[identity];
    final oldDate = DateTime.tryParse('${old?['messageDate']}');
    if (oldDate != null && (date == null || date.isBefore(oldDate))) continue;
    final preview = switch (message['messageType']) {
      'image' => '[图片]',
      'video' => '[视频]',
      'voice' => '[语音]',
      'file' => '[文件]',
      'location' => '[位置]',
      _ => message['text'] as String? ?? '',
    };
    latest[identity] = {
      ...?confirmed,
      'kind': group ? 'group' : 'direct',
      group ? 'groupId' : 'peer': target,
      if (confirmed == null) 'nickname': group ? '群聊' : '好友',
      'preview': message['status'] == 'failed'
          ? '[发送失败] $preview'
          : '[待发送] $preview',
      'messageDate': date?.toUtc().toIso8601String(),
      if (confirmed == null) 'unreadCount': 0,
      if (confirmed == null) '_pendingOnly': true,
    };
  }
  final rows = [
    for (final row in existing) latest.remove(key(row)) ?? row,
    ...latest.values,
  ];
  final ordered = rows.indexed.toList()
    ..sort((a, b) {
      final byDate = '${b.$2['messageDate'] ?? ''}'.compareTo(
        '${a.$2['messageDate'] ?? ''}',
      );
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
  return [for (final row in ordered) row.$2];
}
