import 'call_repository.dart';

/// Optional server-authored metadata; never infer a call from its text label.
class ChatCallHistory {
  const ChatCallHistory(this.id, this.media, this.endReason, this.durationMs);
  final String id;
  final CallMedia media;
  final String endReason;
  final int? durationMs;
  Map<String, dynamic> toJson() => {
    'callId': id,
    'mediaKind': media.name,
    'endReason': endReason,
    'durationMs': durationMs,
  };

  static ChatCallHistory? tryParse(Object? value) {
    if (value is! Map) return null;
    final id = value['callId'], media = value['mediaKind'];
    final reason = value['endReason'], duration = value['durationMs'];
    if (id is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(id) ||
        !['audio', 'video'].contains(media) ||
        ![
          'cancelled',
          'declined',
          'missed',
          'failed',
          'revoked',
          'hangup',
        ].contains(reason) ||
        (duration != null && (duration is! int || duration < 0))) {
      return null;
    }
    return ChatCallHistory(
      id,
      media == 'audio' ? CallMedia.audio : CallMedia.video,
      reason as String,
      duration as int?,
    );
  }
}
