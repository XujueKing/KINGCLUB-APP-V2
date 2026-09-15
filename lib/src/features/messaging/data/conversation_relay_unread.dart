import '../../../core/session/member_qr_memory.dart';
import 'chat_history_store.dart';
import 'messaging_repository.dart';
import '../../auth/domain/auth_repository.dart';

/// Requires the deployed local-receipt conversation contract. Callers must not
/// silently add local counts when the server cannot reconcile identifiers.
Future<Map<String, dynamic>> conversationsWithRelayUnread({
  required MessagingRepository repository,
  required ChatHistoryStore history,
  int offset = 0,
  int limit = 50,
  Set<String> loadedPeers = const {},
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
      final local = await history.nearbyMemberMessages(
        item['peer'] as String,
        limit: 1,
        forPreview: true,
      );
      check();
      if (local.isNotEmpty) {
        final latest = local.single;
        final received = DateTime.fromMillisecondsSinceEpoch(
          latest['created'] as int,
          isUtc: true,
        );
        final serverDate = DateTime.tryParse(
          item['messageDate'] as String? ?? '',
        );
        if (serverDate == null || received.isAfter(serverDate)) {
          item['preview'] = latest['text'];
          item['messageDate'] = received.toIso8601String();
        }
      }
    }
    items.add(item);
  }
  final nextServerOffset = offset + items.length;
  // Only declare a peer local-only once the server pages are exhausted.
  // Earlier page peers are supplied by the list, so none are duplicated here.
  if (result['hasMore'] != true) {
    final seen = {
      ...loadedPeers,
      ...items
          .where((i) => i['kind'] != 'group')
          .map((i) => i['peer'] as String),
    };
    String? afterMember;
    while (true) {
      final members = await history.nearbyConversationMembers(
        afterMember: afterMember,
      );
      check();
      for (final peer in members.where((peer) => !seen.contains(peer))) {
        final local = await history.nearbyMemberMessages(
          peer,
          limit: 1,
          forPreview: true,
        );
        check();
        if (local.isEmpty) continue;
        late List<Map<String, dynamic>> responses;
        try {
          responses = await Future.wait([
            repository.call('K260913000612', {'peer': peer}),
            repository.history(peer, limit: 1),
          ]);
        } on AuthFailure catch (error) {
          check();
          if (error.code == 'PROFILE_UNAVAILABLE' ||
              error.code == 'CHAT_BLOCKED') {
            continue;
          }
          rethrow;
        }
        check();
        final profile = responses[0];
        final head = responses[1];
        final settings = head['settings'] as Map<String, dynamic>;
        final latest = local.single;
        final unread = await history.nearbyUnreadCount(peerAccount: peer);
        check();
        items.add({
          'kind': 'direct',
          'peer': peer,
          'nickname': profile['nickname'],
          'remark': settings['remark'],
          'muted': settings['muted'] == true,
          'pinned': settings['pinned'] == true,
          'lastSequence': head['lastSequence'],
          'preview': latest['text'],
          'unreadCount': unread,
          'relayUnreadCount': unread,
          'messageDate': DateTime.fromMillisecondsSinceEpoch(
            latest['created'] as int,
            isUtc: true,
          ).toIso8601String(),
          'localOnly': true,
        });
        seen.add(peer);
      }
      if (members.length < 100) break;
      afterMember = members.last;
    }
  }
  return {...result, 'items': items, 'nextServerOffset': nextServerOffset};
}
