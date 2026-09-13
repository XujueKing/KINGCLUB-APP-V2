import 'dart:convert';

import 'messaging_repository.dart';
import 'call_relay_configuration.dart';

enum CallPhase { ringing, connecting, active, ended }

enum CallMedia { audio, video }

enum CallAction { accept, decline, cancel, connected, hangup }

bool _uuid(Object? value) =>
    value is String &&
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
int _integer(Object? value, [int max = 4294967295]) {
  if (value is! int || value < 0 || value > max) {
    throw const FormatException('Invalid call number');
  }
  return value;
}

class CallSnapshot {
  CallSnapshot._(
    this.id,
    this.caller,
    this.callee,
    this.media,
    this.phase,
    this.version,
    this.deadlineMs,
    this.endedAtMs,
    this.endReason,
  );
  final String id, caller, callee;
  final CallMedia media;
  final CallPhase phase;
  final int version, deadlineMs;
  final int? endedAtMs;
  final String? endReason;

  factory CallSnapshot.parse(Map<String, dynamic> raw, String account) {
    final id = raw['callId'], caller = raw['caller'], callee = raw['callee'];
    if (!_uuid(id) ||
        caller is! String ||
        callee is! String ||
        caller.isEmpty ||
        callee.isEmpty ||
        caller == callee ||
        (caller != account && callee != account)) {
      throw const FormatException('Invalid call participants');
    }
    final phase = CallPhase.values.byName(raw['phase'] as String);
    final media = CallMedia.values.byName(raw['mediaKind'] as String);
    final reason = raw['endReason'];
    final ended = raw['endedAtMs'];
    if (phase == CallPhase.ended) {
      _integer(ended, 9007199254740991);
      if (!{
        'cancelled',
        'declined',
        'hangup',
        'missed',
        'failed',
        'revoked',
      }.contains(reason)) {
        throw const FormatException('Invalid call end reason');
      }
    } else if (ended != null || reason != null) {
      throw const FormatException('Inconsistent active call');
    }
    return CallSnapshot._(
      id as String,
      caller,
      callee,
      media,
      phase,
      _integer(raw['version']),
      _integer(raw['deadlineMs'], 9007199254740991),
      ended as int?,
      reason as String?,
    );
  }
}

class CallSignal {
  CallSignal(Map<String, dynamic> raw) : data = Map.unmodifiable(raw) {
    if (!_uuid(data['callId']) || !_uuid(data['clientSignalId'])) {
      throw const FormatException('Invalid signal identity');
    }
    _integer(data['generation'], 65535);
    final kind = data['kind'];
    if (kind == 'offer' || kind == 'answer') {
      final sdp = data['sdp'];
      if (sdp is! String ||
          !sdp.startsWith('v=0') ||
          utf8.encode(sdp).length > 65536) {
        throw const FormatException('Invalid SDP');
      }
    } else if (kind == 'ice') {
      final candidate = data['candidate'];
      if (candidate is! String || utf8.encode(candidate).length > 2048) {
        throw const FormatException('Invalid ICE');
      }
    } else {
      throw const FormatException('Unknown signal');
    }
  }
  final Map<String, dynamic> data;
}

class CallSignalPage {
  CallSignalPage(this.items, this.nextSequence, this.generation, this.hasMore);
  final List<({int sequence, CallSignal signal})> items;
  final int nextSequence, generation;
  final bool hasMore;
}

/// Stable request IDs are supplied by the call attempt and reused on retry.
/// Opening a repository never dials, resumes capture or accepts a call.
class CallRepository {
  CallRepository(this.messaging);
  final MessagingRepository messaging;

  Future<CallRelayConfiguration> readRelay({required String callId}) async {
    if (!_uuid(callId)) throw ArgumentError('Invalid call ID');
    final raw = await messaging.call('K260914000648', {'callId': callId});
    return CallRelayConfiguration.parse(callId, raw);
  }

  Future<int> sendSignal(CallSignal signal) async {
    final raw = await messaging.call('K260913000646', {'signal': signal.data});
    final sequence = _integer(raw['sequence']);
    if (sequence == 0 ||
        raw['generation'] != signal.data['generation'] ||
        raw['replay'] is! bool) {
      throw const FormatException('Invalid signal acknowledgement');
    }
    return sequence;
  }

  Future<CallSignalPage> readSignals({
    required String callId,
    int after = 0,
    bool renewLease = true,
  }) async {
    if (!_uuid(callId)) throw ArgumentError('Invalid call ID');
    _integer(after);
    final raw = await messaging.call('K260913000647', {
      'callId': callId,
      'after': after,
      'limit': 50,
      'renewLease': renewLease,
    });
    final generation = _integer(raw['generation'], 65535);
    final rows = raw['items'];
    if (rows is! List || rows.length > 50 || raw['hasMore'] is! bool) {
      throw const FormatException('Invalid signal page');
    }
    final items = <({int sequence, CallSignal signal})>[];
    var previous = after;
    for (final row in rows) {
      final sequence = _integer((row as Map)['sequence']);
      final signal = CallSignal(
        Map<String, dynamic>.from(row['signal'] as Map),
      );
      if (sequence <= previous ||
          signal.data['callId'] != callId ||
          signal.data['generation'] != generation) {
        throw const FormatException('Signal page mismatch');
      }
      items.add((sequence: sequence, signal: signal));
      previous = sequence;
    }
    if (raw['nextSequence'] != previous ||
        (rows.isEmpty && raw['hasMore'] == true)) {
      throw const FormatException('Invalid signal cursor');
    }
    return CallSignalPage(
      List.unmodifiable(items),
      previous,
      generation,
      raw['hasMore'] as bool,
    );
  }

  Future<CallSnapshot> start({
    required String peer,
    required CallMedia media,
    required String requestId,
  }) async {
    if (peer.isEmpty || peer == messaging.account || !_uuid(requestId)) {
      throw ArgumentError('Invalid call request');
    }
    final raw = await messaging.call('K260913000643', {
      'peer': peer,
      'mediaKind': media.name,
      'requestId': requestId,
    });
    final call = CallSnapshot.parse(raw, messaging.account);
    if (call.caller != messaging.account ||
        call.callee != peer ||
        call.media != media) {
      throw const FormatException('Call acknowledgement mismatch');
    }
    return call;
  }

  Future<CallSnapshot?> read({String? callId}) async {
    if (callId != null && !_uuid(callId)) {
      throw ArgumentError('Invalid call ID');
    }
    final raw = await messaging.call('K260913000645', {'callId': ?callId});
    if (!raw.containsKey('call')) {
      throw const FormatException('Missing call result');
    }
    if (raw['call'] == null) {
      if (callId != null) throw const FormatException('Missing requested call');
      return null;
    }
    final call = CallSnapshot.parse(
      Map<String, dynamic>.from(raw['call'] as Map),
      messaging.account,
    );
    if (callId != null && call.id != callId) {
      throw const FormatException('Wrong call returned');
    }
    return call;
  }

  Future<CallSnapshot> act({
    required CallSnapshot call,
    required CallAction action,
    required String requestId,
  }) async {
    if (!_uuid(requestId) ||
        (call.caller != messaging.account &&
            call.callee != messaging.account)) {
      throw ArgumentError('Invalid call action');
    }
    final raw = await messaging.call('K260913000644', {
      'callId': call.id,
      'requestId': requestId,
      'expectedVersion': call.version,
      'action': action.name,
    });
    final next = CallSnapshot.parse(raw, messaging.account);
    if (next.id != call.id ||
        next.caller != call.caller ||
        next.callee != call.callee ||
        next.media != call.media ||
        next.version < call.version) {
      throw const FormatException('Call action acknowledgement mismatch');
    }
    return next;
  }
}
