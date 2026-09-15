import '../../../core/session/member_qr_memory.dart';
import 'chat_history_store.dart';
import 'messaging_repository.dart';

/// Requires the deployed local-receipt conversation contract. Callers must not
/// silently add local counts when the server cannot reconcile identifiers.
Future<Map<String, dynamic>> conversationsWithRelayUnread({
  required MessagingRepository repository,
  required ChatHistoryStore history,
  int offset = 0,
  int limit = 50,
}) async {
  if (history.account != repository.account) {
    throw StateError('History account mismatch');
  }
  final generation = MemberQrMemory.generation;
  void check() {
    if (generation != MemberQrMemory.generation) {
      throw StateError('Chat account changed');
    }
  }

  String? cursor;
  Map<String, dynamic>? result;
  while (true) {
    check();
    final ids = await history.nearbyUnreadIds(afterId: cursor);
    check();
    if (ids.isEmpty) break;
    result = await repository.conversations(
      offset: offset,
      limit: limit,
      knownLocalMessageIds: ids,
    );
    check();
    for (final item in result['items'] as List) {
      if (item['kind'] == 'group') continue;
      await history.confirmNearbyServerPresence(
        item['peer'] as String,
        (item['confirmedLocalMessageIds'] as List).cast<String>(),
      );
      check();
    }
    cursor = ids.last;
    if (ids.length < 200) break;
  }
  result ??= await repository.conversations(offset: offset, limit: limit);
  check();
  final items = <Map<String, dynamic>>[];
  for (final raw in result['items'] as List) {
    final item = Map<String, dynamic>.from(raw as Map);
    if (item['kind'] != 'group') {
      final extra = await history.nearbyUnreadCount(
        peerAccount: item['peer'] as String,
      );
      check();
      item['relayUnreadCount'] = extra;
      item['unreadCount'] = (item['unreadCount'] as num).toInt() + extra;
    }
    items.add(item);
  }
  return {...result, 'items': items};
}
