/// Preserve server sequence order while inserting local messages by observed
/// time. Missing local times remain at the end, without inventing timestamps.
List<Map<String, dynamic>> mergeLocalChatMessages(
  Iterable<Map<String, dynamic>> confirmed,
  Iterable<Map<String, dynamic>> local,
) {
  DateTime? time(Map<String, dynamic> row) =>
      DateTime.tryParse(row['createdDate'] as String? ?? '');
  final additions = local.indexed.toList()
    ..sort((a, b) {
      final left = time(a.$2), right = time(b.$2);
      final order = left == null
          ? (right == null ? 0 : 1)
          : right == null
          ? -1
          : left.compareTo(right);
      return order == 0 ? a.$1.compareTo(b.$1) : order;
    });
  final result = <Map<String, dynamic>>[];
  var index = 0;
  for (final row in confirmed) {
    final timestamp = time(row);
    if (timestamp != null) {
      while (index < additions.length) {
        final localTime = time(additions[index].$2);
        if (localTime == null || localTime.isAfter(timestamp)) break;
        result.add(additions[index++].$2);
      }
    }
    result.add(row);
  }
  result.addAll(additions.skip(index).map((entry) => entry.$2));
  return result;
}
