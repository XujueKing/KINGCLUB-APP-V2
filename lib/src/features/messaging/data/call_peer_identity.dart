import 'messaging_repository.dart';

/// Read from our authenticated service, never from a vendor push payload.
Future<String?> callPeerName(
  MessagingRepository repository,
  String peer,
) async {
  Future<Map<String, dynamic>> optional(
    Future<Map<String, dynamic>> Function() read,
  ) async {
    try {
      return await read();
    } catch (_) {
      return {};
    }
  }

  final values = await Future.wait([
    optional(() => repository.settings(peer)),
    optional(() => repository.call('K260913000612', {'peer': peer})),
  ]);
  for (final raw in [values[0]['remark'], values[1]['nickname']]) {
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
    }
  }
  return null;
}
