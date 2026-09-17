/// Only clear server unread counts when the complete server head was viewed.
/// Sequence gaps include outgoing/deleted messages, so partial counts cannot
/// safely be computed by subtracting sequence numbers.
class ConversationReadProjection {
  const ConversationReadProjection(this.direct, this.groups);
  final Map<String, int> direct;
  final Map<String, int> groups;

  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> rows) => [
    for (final row in rows) _apply(row),
  ];

  Map<String, dynamic> _apply(Map<String, dynamic> row) {
    final group = row['kind'] == 'group';
    final watermark = (group
        ? groups
        : direct)[row[group ? 'groupId' : 'peer']];
    final head = row['lastSequence'];
    if (watermark == null || head is! int || head < 0 || watermark < head) {
      return Map<String, dynamic>.from(row);
    }
    // Nearby messages have separate identifiers and independent read state.
    return {...row, 'unreadCount': group ? 0 : (row['relayUnreadCount'] ?? 0)};
  }
}
