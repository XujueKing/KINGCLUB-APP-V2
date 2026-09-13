/// In-memory credentials for exactly one call. Do not persist or log this
/// object: TURN credentials remain bearer credentials until their expiry.
class CallRelayConfiguration {
  CallRelayConfiguration._(this.callId, this.expiresAtMs, this.iceServers);
  final String callId;
  final int expiresAtMs;
  final List<Map<String, dynamic>> iceServers;

  factory CallRelayConfiguration.parse(
    String callId,
    Map<String, dynamic> raw, {
    int? nowMs,
  }) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(callId)) {
      throw const FormatException('Invalid relay call ID');
    }
    final expiry = raw['expiresAtMs'], servers = raw['iceServers'];
    if (expiry is! int ||
        expiry <= now + 15000 ||
        expiry > now + 3660000 ||
        servers is! List ||
        servers.isEmpty ||
        servers.length > 8) {
      throw const FormatException('Invalid relay lifetime or server count');
    }
    final result = <Map<String, dynamic>>[];
    for (final server in servers) {
      if (server is! Map) throw const FormatException('Invalid relay server');
      final urls = server['urls'],
          username = server['username'],
          credential = server['credential'];
      if (urls is! List ||
          urls.isEmpty ||
          urls.length > 8 ||
          username is! String ||
          !RegExp(r'^\d{1,13}:[a-f0-9]{32}$').hasMatch(username) ||
          int.parse(username.split(':').first) * 1000 != expiry ||
          credential is! String ||
          !RegExp(r'^[A-Za-z0-9+/]{27}=$').hasMatch(credential)) {
        throw const FormatException('Invalid relay credentials');
      }
      final checkedUrls = <String>[];
      for (final url in urls) {
        final match = url is String && url.length <= 256
            ? RegExp(
                r'^(turns?):(\[[0-9a-fA-F:]+\]|[A-Za-z0-9][A-Za-z0-9.-]*)(?::([0-9]{1,5}))?(?:\?transport=(udp|tcp))?$',
              ).firstMatch(url)
            : null;
        final port = match?.group(3) == null
            ? null
            : int.parse(match!.group(3)!);
        if (match == null ||
            (port != null && (port < 1 || port > 65535)) ||
            (match.group(1) == 'turns' && match.group(4) == 'udp')) {
          throw const FormatException('Invalid relay URL');
        }
        checkedUrls.add(url as String);
      }
      result.add(
        Map.unmodifiable({
          'urls': List<String>.unmodifiable(checkedUrls),
          'username': username,
          'credential': credential,
        }),
      );
    }
    return CallRelayConfiguration._(callId, expiry, List.unmodifiable(result));
  }

  void requireUsable(String expectedCallId, {int? nowMs}) {
    if (expectedCallId != callId ||
        expiresAtMs <=
            (nowMs ?? DateTime.now().millisecondsSinceEpoch) + 15000) {
      throw StateError('Call relay configuration expired or mismatched');
    }
  }
}
