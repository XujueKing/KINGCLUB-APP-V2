/// Unknown scope remains conservative; only an explicit unrelated scope is
/// ignored. Group notifications cannot change a direct-message permission.
bool affectsChatMedia(
  Map<String, dynamic> event, {
  required bool group,
  String? scopeId,
}) {
  final type = event['eventType'];
  if (type == 'connection.ready') return true;
  final groupEvent = type == 'chat.group.changed' || type == 'chat.group.read';
  if (!groupEvent &&
      type != 'chat.settings.changed' &&
      type != 'chat.relationship.changed') {
    return false;
  }
  if (groupEvent && !group) return false;
  final data = event['data'];
  if (data is! Map) return true;
  final scope = data[groupEvent ? 'groupId' : 'conversationId'];
  if (scope is! String || scope.isEmpty) return true;
  if (group && !groupEvent) return false;
  return scopeId == null || scope == scopeId;
}
