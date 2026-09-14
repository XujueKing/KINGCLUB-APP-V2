typedef ContextHistoryReader = Future<Map<String, dynamic>> Function({
  int? before,
  int? after,
  required int limit,
});

/// Reads a bounded window without changing the conversation's catch-up cursor.
Future<List<Map<String, dynamic>>> readChatHistoryContext({
  required ContextHistoryReader read,
  required String messageId,
  required int sequence,
}) async {
  if (messageId.isEmpty || sequence < 1 || sequence > 4294967295) {
    throw ArgumentError('Invalid message reference');
  }
  // The upper sequence boundary is exclusive. At the maximum sequence there
  // cannot be a newer message, so the ordinary newest page is sufficient.
  final older = await read(
    before: sequence == 4294967295 ? null : sequence + 1,
    limit: 21,
  );
  final newer = await read(after: sequence, limit: 20);
  if (older['membershipVersion'] != newer['membershipVersion']) {
    throw StateError('Group membership changed while locating the message');
  }
  for (final page in [older, newer]) {
    final revision = page['historyVersion'];
    if (revision != null &&
        (revision is! int || revision < 0 || revision > 4294967295)) {
      throw const FormatException('Invalid history revision');
    }
  }
  if (older['historyVersion'] != newer['historyVersion']) {
    throw StateError('History changed while locating the message');
  }
  final settings = newer['settings'];
  if (settings is! Map || settings['hiddenThrough'] is! int) {
    throw const FormatException('Missing history visibility boundary');
  }
  final hidden = settings['hiddenThrough'] as int;
  final joined = newer['joinedSequence'];
  if (newer['membershipVersion'] != null && joined is! int) {
    throw const FormatException('Missing group admission boundary');
  }
  final lower = joined is int && joined > hidden ? joined : hidden;
  final messages = <int, Map<String, dynamic>>{};
  for (final page in [older, newer]) {
    final raw = page['messages'];
    if (raw is! List) throw const FormatException('Invalid history page');
    for (final value in raw) {
      final row = Map<String, dynamic>.from(value as Map);
      final number = row['sequence'];
      if (number is! int || row['messageId'] is! String) {
        throw const FormatException('Invalid history message');
      }
      if (number > lower) messages[number] = row;
    }
  }
  if (messages[sequence]?['messageId'] != messageId) {
    throw StateError('The message is no longer available');
  }
  final sorted = messages.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return sorted.map((entry) => entry.value).toList();
}
