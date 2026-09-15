import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart'
    show
        RtpCapabilities,
        RtpParameters,
        IceParameters,
        IceCandidate,
        DtlsParameters;

import 'call_repository.dart' show CallMedia;
import 'call_relay_configuration.dart';
import 'group_call_repository.dart';
import 'messaging_repository.dart';

String _id(Object? value) {
  if (value is! String ||
      !RegExp(r'^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
          .hasMatch(value)) {
    throw const FormatException('Invalid media identity');
  }
  return value;
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid media object');
  }
  return value;
}

String _kind(Object? value) {
  if (value != 'audio' && value != 'video') {
    throw const FormatException('Invalid media kind');
  }
  return value as String;
}

class GroupMediaSource {
  const GroupMediaSource(this.producerId, this.account, this.kind, this.paused);
  final String producerId, account, kind;
  final bool paused;
}

class GroupMediaTransport {
  const GroupMediaTransport(
    this.id,
    this.iceParameters,
    this.iceCandidates,
    this.dtlsParameters,
  );
  final String id;
  final IceParameters iceParameters;
  final List<IceCandidate> iceCandidates;
  final DtlsParameters dtlsParameters;
}

class GroupMediaConsumer {
  const GroupMediaConsumer(this.id, this.source, this.rtpParameters);
  final String id;
  final GroupMediaSource source;
  final RtpParameters rtpParameters;
}

/// Bound to a single known call. No capture or networking in the constructor.
class GroupCallMediaRepository {
  GroupCallMediaRepository(this.messaging, this.call)
    : _members = Set.unmodifiable(call.participants.map((p) => p.account)) {
    if (!_members.contains(messaging.account)) {
      throw const FormatException('Current account is not a participant');
    }
  }
  final MessagingRepository messaging;
  final GroupCallSnapshot call;
  final Set<String> _members;
  bool _closed = false;
  void close() {
    _closed = true;
  }

  void _check() {
    if (_closed) {
      throw StateError('Group media closed');
    }
  }

  Future<Map<String, dynamic>> _send(Map<String, dynamic> command) async {
    _check();
    final value = await messaging.call('K260915000682', {
      'callId': call.id,
      'command': command,
    });
    _check();
    return value;
  }

  Future<CallRelayConfiguration> readRelay() async =>
      CallRelayConfiguration.parse(call.id, await _send({'type': 'relay'}));

  Future<RtpCapabilities> capabilities() async {
    final result = await _send({'type': 'capabilities'});
    final raw = _object(result['rtpCapabilities']);
    if (raw['codecs'] is! List || (raw['codecs'] as List).isEmpty) {
      throw const FormatException('Missing media codecs');
    }
    return RtpCapabilities.fromMap(raw);
  }

  Future<GroupMediaTransport> createTransport({required bool sending}) async {
    final result = await _send({
      'type': 'createTransport',
      'direction': sending ? 'send' : 'receive',
    });
    final raw = _object(result['transport']);
    final id = _id(raw['id']);
    final candidates = raw['iceCandidates'];
    if (candidates is! List || candidates.isEmpty || candidates.length > 32) {
      throw const FormatException('Invalid ICE candidates');
    }
    return GroupMediaTransport(
      id,
      IceParameters.fromMap(_object(raw['iceParameters'])),
      List.unmodifiable(
        candidates.map((c) => IceCandidate.fromMap(_object(c))),
      ),
      DtlsParameters.fromMap(_object(raw['dtlsParameters'])),
    );
  }

  Future<void> connect(String transportId, DtlsParameters dtls) async {
    final result = await _send({
      'type': 'connect',
      'transportId': _id(transportId),
      'dtlsParameters': dtls.toMap(),
    });
    if (result['connected'] != true) {
      throw const FormatException('Media connection not acknowledged');
    }
  }

  Future<String> produce(
    String transportId,
    String kind,
    RtpParameters rtp,
  ) async {
    _kind(kind);
    if (kind == 'video' && call.media == CallMedia.audio) {
      throw StateError('Audio-only call');
    }
    final result = await _send({
      'type': 'produce',
      'transportId': _id(transportId),
      'kind': kind,
      'rtpParameters': rtp.toMap(),
    });
    final raw = _object(result['producer']);
    if (raw['kind'] != kind) {
      throw const FormatException('Producer kind mismatch');
    }
    return _id(raw['id']);
  }

  Future<List<GroupMediaSource>> sources() async {
    final result = await _send({'type': 'sources'});
    final rows = result['sources'];
    if (rows is! List || rows.length > 16) {
      throw const FormatException('Invalid media sources');
    }
    final seen = <String>{};
    final tracks = <String>{};
    final sources = <GroupMediaSource>[];
    for (final row in rows) {
      final raw = _object(row), id = _id(row['producerId']);
      final account = raw['userAccount'], kind = _kind(raw['kind']);
      if (account is! String ||
          account == messaging.account ||
          !_members.contains(account) ||
          raw['paused'] is! bool ||
          !seen.add(id) ||
          !tracks.add('$account:$kind') ||
          (kind == 'video' && call.media == CallMedia.audio)) {
        throw const FormatException('Invalid media source ownership');
      }
      sources.add(GroupMediaSource(id, account, kind, raw['paused'] as bool));
    }
    return List.unmodifiable(sources);
  }

  Future<GroupMediaConsumer> consume(
    String transportId,
    GroupMediaSource source,
    RtpCapabilities capabilities,
  ) async {
    if (!_members.contains(source.account) ||
        source.account == messaging.account) {
      throw const FormatException('Invalid media source ownership');
    }
    final result = await _send({
      'type': 'consume',
      'transportId': _id(transportId),
      'producerId': _id(source.producerId),
      'rtpCapabilities': capabilities.toMap(),
    });
    final raw = _object(result['consumer']);
    if (raw['producerId'] != source.producerId || raw['kind'] != source.kind) {
      throw const FormatException('Consumer source mismatch');
    }
    return GroupMediaConsumer(
      _id(raw['id']),
      source,
      RtpParameters.fromMap(_object(raw['rtpParameters'])),
    );
  }

  Future<void> resumeConsumer(String consumerId) async {
    final result = await _send({
      'type': 'resumeConsumer',
      'consumerId': _id(consumerId),
    });
    if (result['resumed'] != true) {
      throw const FormatException('Consumer not resumed');
    }
  }

  Future<void> setProducerPaused(String producerId, bool paused) async {
    final result = await _send({
      'type': 'setProducerPaused',
      'producerId': _id(producerId),
      'paused': paused,
    });
    if (result['producerId'] != producerId || result['paused'] != paused) {
      throw const FormatException('Producer state mismatch');
    }
  }

  Future<void> closeProducer(String producerId) async {
    final result = await _send({
      'type': 'closeProducer',
      'producerId': _id(producerId),
    });
    if (result['closed'] != true) {
      throw const FormatException('Producer not closed');
    }
  }
}
