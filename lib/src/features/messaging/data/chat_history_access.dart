import '../../auth/domain/auth_repository.dart';
import 'chat_history_store.dart';

/// A definitive group-access rejection revokes its cached history everywhere.
/// Other errors (including network failures and direct-chat restrictions) do not.
Future<void> clearDeniedGroupHistory(
  Object error, {
  required String account,
  required String? groupId,
  Future<ChatHistoryStore> Function()? openHistory,
}) async {
  if (error is! AuthFailure ||
      error.code != 'CHAT_GROUP_ACCESS_DENIED' ||
      groupId == null ||
      groupId.isEmpty) {
    return;
  }
  final store = await (openHistory?.call() ?? ChatHistoryStore.open(account));
  if (store.account != account) throw StateError('History account mismatch');
  await store.clear('group:$groupId', deleteMedia: false);
}
