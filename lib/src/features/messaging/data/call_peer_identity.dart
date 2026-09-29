import 'messaging_repository.dart';

/// Read from our authenticated service, never from a vendor push payload.
Future<String?> callPeerName(
  MessagingRepository repository,
  String peer,
) async {
  Map<String, dynamic> profile;
  try {
    profile = await repository.call('K260913000612', {'peer': peer});
  } catch (_) {
    return null;
  }
  for (final raw in [profile['remark'], profile['nickname']]) {
    if (raw is String && raw.trim().isNotEmpty) {
      final name = raw.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
      if (name.isNotEmpty) return name;
    }
  }
  return null;
}
