import 'call_repository.dart' show CallMedia;
import 'messaging_repository.dart';

enum GroupCallPhase { invited, joined, left, declined, expired, revoked }

enum GroupCallAction { join, decline, leave, heartbeat }

bool _uuid(Object? value) =>
    value is String &&
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
bool _account(Object? value) =>
    value is String && RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(value);
int _number(Object? value, [int max = 4294967294]) {
  if (value is! int || value < 0 || value > max) {
    throw const FormatException('Invalid group call number');
  }
  return value;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid group call object');
  }
  return value;
}

class GroupCallParticipant {
  const GroupCallParticipant._(this.account, this.phase, this.deadlineMs);
  final String account;
  final GroupCallPhase phase;
  final int deadlineMs;
  bool get isActive =>
      phase == GroupCallPhase.invited || phase == GroupCallPhase.joined;
}

class GroupCallSnapshot {
  const GroupCallSnapshot._(
    this.id,
    this.groupId,
    this.media,
    this.version,
    this.endedAtMs,
    this.participants,
  );
  final String id, groupId;
  final CallMedia media;
  final int version;
  final int? endedAtMs;
  final List<GroupCallParticipant> participants;

  factory GroupCallSnapshot.parse(Map<String, dynamic> raw, String account) {
    if (!_uuid(raw['callId']) || !_uuid(raw['groupId'])) {
      throw const FormatException('Invalid group call identity');
    }
    final media = switch (raw['mediaKind']) {
      'audio' => CallMedia.audio,
      'video' => CallMedia.video,
      _ => throw const FormatException('Invalid group call media'),
    };
    final rows = raw['participants'];
    if (rows is! List || rows.length < 2 || rows.length > 9) {
      throw const FormatException('Invalid group call participants');
    }
    final seen = <String>{};
    final participants = <GroupCallParticipant>[];
    for (final row in rows) {
      final p = _map(row);
      if (!_account(p['account']) ||
          !seen.add(p['account'] as String) ||
          p.containsKey('sessionId') ||
          p.containsKey('session')) {
        throw const FormatException('Invalid group call participant');
      }
      final phase = switch (p['phase']) {
        'invited' => GroupCallPhase.invited,
        'joined' => GroupCallPhase.joined,
        'left' => GroupCallPhase.left,
        'declined' => GroupCallPhase.declined,
        'expired' => GroupCallPhase.expired,
        'revoked' => GroupCallPhase.revoked,
        _ => throw const FormatException('Invalid group call phase'),
      };
      participants.add(
        GroupCallParticipant._(
          p['account'] as String,
          phase,
          _number(p['deadlineMs'], 9007199254740991),
        ),
      );
    }
    final ended = raw['endedAtMs'];
    if (!raw.containsKey('endedAtMs') ||
        !seen.contains(account) ||
        (ended == null) !=
            participants.any((p) => p.phase == GroupCallPhase.joined)) {
      throw const FormatException('Inconsistent group call state');
    }
    return GroupCallSnapshot._(
      raw['callId'] as String,
      raw['groupId'] as String,
      media,
      _number(raw['version']),
      ended == null ? null : _number(ended, 9007199254740991),
      List.unmodifiable(participants),
    );
  }
}

class GroupCallResult {
  const GroupCallResult(this.call, this.appliedVersion, this.replay);
  final GroupCallSnapshot call;
  final int appliedVersion;
  final bool replay;
}

/// Reuses the session-bound encrypted messaging client. No capture, automatic
/// dialing or retry is performed here; callers retain the same request ID.
class GroupCallRepository {
  const GroupCallRepository(this.messaging);
  final MessagingRepository messaging;

  GroupCallResult _result(Map<String, dynamic> raw, int appliedVersion) {
    final call = GroupCallSnapshot.parse(raw, messaging.account);
    if (raw['replay'] is! bool ||
        _number(raw['appliedVersion']) != appliedVersion ||
        call.version < appliedVersion) {
      throw const FormatException('Invalid group call acknowledgement');
    }
    return GroupCallResult(call, appliedVersion, raw['replay'] as bool);
  }

  Future<GroupCallResult> start({
    required String groupId,
    required List<String> invitees,
    required CallMedia media,
    required String requestId,
  }) async {
    if (!_uuid(groupId) ||
        !_uuid(requestId) ||
        invitees.isEmpty ||
        invitees.length > 8 ||
        invitees.any((a) => !_account(a) || a == messaging.account) ||
        invitees.toSet().length != invitees.length) {
      throw ArgumentError('Invalid group call request');
    }
    final accounts = {messaging.account, ...invitees};
    final result = _result(
      await messaging.call('K260915000678', {
        'groupId': groupId,
        'invitees': List<String>.of(invitees),
        'mediaKind': media.name,
        'requestId': requestId,
      }),
      0,
    );
    if (result.call.groupId != groupId ||
        result.call.media != media ||
        result.call.participants.length != accounts.length ||
        !result.call.participants.every((p) => accounts.contains(p.account))) {
      throw const FormatException('Group call target mismatch');
    }
    return result;
  }

  Future<GroupCallSnapshot> read(String callId) async {
    if (!_uuid(callId)) throw ArgumentError('Invalid group call ID');
    final call = GroupCallSnapshot.parse(
      await messaging.call('K260915000680', {'callId': callId}),
      messaging.account,
    );
    if (call.id != callId) {
      throw const FormatException('Group call ID mismatch');
    }
    return call;
  }

  Future<GroupCallSnapshot?> current() async {
    final raw = await messaging.call('K260915000681', {});
    if (!raw.containsKey('call')) {
      throw const FormatException('Missing current group call');
    }
    if (raw['call'] == null) return null;
    final call = GroupCallSnapshot.parse(_map(raw['call']), messaging.account);
    if (call.endedAtMs != null ||
        !call.participants
            .singleWhere((p) => p.account == messaging.account)
            .isActive) {
      throw const FormatException('Inactive current group call');
    }
    return call;
  }

  Future<GroupCallResult> act({
    required GroupCallSnapshot call,
    required GroupCallAction action,
    required String requestId,
  }) async {
    if (!_uuid(requestId) ||
        call.version >= 4294967294 ||
        !call.participants.any((p) => p.account == messaging.account)) {
      throw ArgumentError('Invalid group call action');
    }
    final result = _result(
      await messaging.call('K260915000679', {
        'callId': call.id,
        'requestId': requestId,
        'expectedVersion': call.version,
        'action': action.name,
      }),
      call.version + 1,
    );
    final accounts = call.participants.map((p) => p.account).toSet();
    if (result.call.id != call.id ||
        result.call.groupId != call.groupId ||
        result.call.media != call.media ||
        result.call.participants.length != accounts.length ||
        !result.call.participants.every((p) => accounts.contains(p.account))) {
      throw const FormatException('Group call action mismatch');
    }
    return result;
  }
}
