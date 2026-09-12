import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/data/auth_repository_provider.dart';
import '../session/secure_session_store.dart';

String _b64(List<int> v) => base64Url.encode(v).replaceAll('=', '');
List<int> _decode(String v) => base64Url.decode(base64Url.normalize(v));
String _hex(List<int> v) =>
    v.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// The existing CCSOP authenticated and encrypted WebSocket protocol.
class RealtimeCodec {
  RealtimeCodec(
    this.session,
    this.clientId, {
    String? timestamp,
    String? nonce,
    String? requestId,
  }) : timestamp =
           timestamp ?? DateTime.now().millisecondsSinceEpoch.toString(),
       nonce = nonce ?? 'nonce_${const Uuid().v4()}',
       requestId = requestId ?? 'request_${const Uuid().v4()}';
  final Map<String, dynamic> session;
  final String clientId;
  final String timestamp, nonce, requestId;
  int _sequence = 0;
  Future<SecretKey> _key(String purpose) =>
      Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKey(utf8.encode(session['apiKey'] as String)),
        nonce: utf8.encode('$timestamp:$nonce'),
        info: utf8.encode('ccsop:websocket:$purpose:$requestId'),
      );
  Future<Uri> uri(String base) async {
    final values = <String, String>{
      'apiKeyId': session['apiKeyId'] as String,
      'sessionId': session['sessionId'] as String,
      'timestamp': timestamp,
      'nonce': nonce,
      'requestId': requestId,
      'clientId': clientId,
    };
    final canonical = [
      'GET',
      '/ws',
      values['apiKeyId'],
      values['sessionId'],
      timestamp,
      nonce,
      requestId,
      _hex((await Sha256().hash(utf8.encode(clientId))).bytes),
    ].join('\n');
    values['sign'] = _b64(
      (await Hmac.sha256().calculateMac(
        utf8.encode(canonical),
        secretKey: await _key('sign'),
      )).bytes,
    );
    final root = Uri.parse(base);
    return root.replace(
      scheme: root.scheme == 'https' ? 'wss' : 'ws',
      path: '${root.path.replaceFirst(RegExp(r'/$'), '')}/ws',
      queryParameters: values,
    );
  }

  Future<Map<String, dynamic>> decode(String raw) async {
    final frame = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (frame['encrypted'] != true ||
        frame['seq'] is! int ||
        (frame['seq'] as int) <= _sequence) {
      throw const FormatException('Invalid realtime sequence');
    }
    final payload = Map<String, dynamic>.from(frame['data'] as Map);
    final canonical = [
      frame['eventType'],
      frame['seq'],
      frame['timestamp'],
      frame['traceId'] ?? '',
      _hex((await Sha256().hash(utf8.encode(jsonEncode(payload)))).bytes),
    ].join('\n');
    final expected = await Hmac.sha256().calculateMac(
      utf8.encode(canonical),
      secretKey: await _key('message-sign'),
    );
    final received = _decode(frame['sign'] as String);
    var difference = expected.bytes.length ^ received.length;
    for (var i = 0; i < min(expected.bytes.length, received.length); i++) {
      difference |= expected.bytes[i] ^ received[i];
    }
    if (difference != 0) {
      throw const FormatException('Invalid realtime signature');
    }
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(
        _decode(payload['ciphertext'] as String),
        nonce: _decode(payload['iv'] as String),
        mac: Mac(_decode(payload['tag'] as String)),
      ),
      secretKey: await _key('server-to-client'),
    );
    _sequence = frame['seq'] as int;
    return {...frame, 'data': jsonDecode(utf8.decode(clear))};
  }
}

class KingclubRealtime {
  static final shared = KingclubRealtime();
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;
  WebSocket? _socket;
  Timer? _retry;
  bool _active = false;
  int _epoch = 0, _attempt = 0;
  String? _sessionId;
  final _seen = <String>{};
  bool get connected => _socket?.readyState == WebSocket.open;
  Future<void> start() async {
    _active = true;
    await reconnect();
  }

  void stop() {
    _active = false;
    _epoch++;
    _retry?.cancel();
    _socket?.close();
    _socket = null;
    _sessionId = null;
    _seen.clear();
  }

  Future<void> reconnect() async {
    if (!_active || kingclubApiBaseUrl.isEmpty) return;
    final epoch = ++_epoch;
    _retry?.cancel();
    _socket?.close();
    _socket = null;
    try {
      final session = await SecureSessionStore().readSession();
      if (epoch != _epoch || !_active || session == null) return;
      if (_sessionId != session['sessionId']) _seen.clear();
      _sessionId = session['sessionId'] as String;
      final codec = RealtimeCodec(
        session,
        await SecureSessionStore().deviceId(),
      );
      final socket = await WebSocket.connect(
        (await codec.uri(kingclubApiBaseUrl)).toString(),
      ).timeout(const Duration(seconds: 10));
      if (epoch != _epoch || !_active) {
        await socket.close();
        return;
      }
      _socket = socket;
      socket.pingInterval = const Duration(seconds: 25);
      Future<void> serial = Future.value();
      socket.listen(
        (raw) {
          serial = serial
              .then((_) async {
                if (epoch != _epoch) return;
                final event = await codec.decode(raw as String);
                if (epoch != _epoch) return;
                if (event['eventType'] == 'connection.ready') _attempt = 0;
                final data = event['data'];
                final id = data is Map
                    ? data['notificationId'] ?? data['eventId']
                    : null;
                if (id is String) {
                  if (!_seen.add(id)) return;
                  if (_seen.length > 200) _seen.remove(_seen.first);
                }
                _events.add(event);
              })
              .catchError((Object e) {
                socket.close();
              });
        },
        onDone: () => _schedule(epoch),
        onError: (Object e) => _schedule(epoch),
      );
    } catch (_) {
      _schedule(epoch);
    }
  }

  void _schedule(int epoch) {
    if (!_active || epoch != _epoch || (_retry?.isActive ?? false)) return;
    _socket = null;
    _retry = Timer(
      Duration(seconds: min(30, 1 << min(_attempt++, 5))),
      reconnect,
    );
  }
}
