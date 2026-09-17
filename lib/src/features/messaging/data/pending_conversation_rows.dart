/// Missing conversations remain reachable while their first message is queued.
/// These are display-only rows, never server pagination or unread-count inputs.
List<Map<String, dynamic>> pendingConversationRows(
  String account,
  List<Map<String, dynamic>> existing,
  List<Map<String, dynamic>> pending,
) {
  String key(Map<String, dynamic> row) => row['kind'] == 'group'
      ? 'group:${row['groupId']}'
      : 'peer:${row['peer']}';
  final known = existing.map(key).toSet();
  final latest = <String, Map<String, dynamic>>{};
  for (final message in pending) {
    if (message['sender'] != account) continue;
    final group = message['groupId'] is String;
    final target = message[group ? 'groupId' : 'recipient'];
    if (target is! String || target.isEmpty) continue;
    final identity = '${group ? 'group' : 'peer'}:$target';
    if (known.contains(identity)) continue;
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
      'kind': group ? 'group' : 'direct',
      group ? 'groupId' : 'peer': target,
      'nickname': group ? '群聊' : '好友',
      'preview': '[待发送] $preview',
      'messageDate': date?.toUtc().toIso8601String(),
      'unreadCount': 0,
      '_pendingOnly': true,
    };
  }
  final rows = latest.values.toList()
    ..sort(
      (a, b) =>
          '${b['messageDate'] ?? ''}'.compareTo('${a['messageDate'] ?? ''}'),
    );
  return [...rows, ...existing];
}
