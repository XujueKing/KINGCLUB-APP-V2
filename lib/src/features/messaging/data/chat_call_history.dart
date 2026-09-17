import 'call_repository.dart';

/// Optional server-authored metadata; never infer a call from its text label.
class ChatCallHistory {
  const ChatCallHistory(
    this.id,
    this.media,
    this.endReason,
    this.durationMs, {
    this.groupId,
  });
  final String id;
  final String? groupId;
  final CallMedia media;
  final String endReason;
  final int? durationMs;

  String displayText({required bool outgoing}) {
    final label =
        '${groupId == null ? '' : '群'}${media == CallMedia.video ? '视频通话' : '语音通话'}';
    final duration = durationMs;
    if (duration != null) {
      final seconds = duration ~/ 1000;
      final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
      final remainder = (seconds % 60).toString().padLeft(2, '0');
      return '$label · $minutes:$remainder'
          '${endReason == 'failed' ? ' · 连接中断' : ''}';
    }
    final status = switch (endReason) {
      'cancelled' => outgoing ? '已取消' : '对方已取消',
      'declined' => outgoing ? '对方已拒绝' : '已拒绝',
      'missed' => outgoing ? '对方未接听' : '未接听',
      'failed' => '连接中断',
      _ => '通话已结束',
    };
    return '$label · $status';
  }

  Map<String, dynamic> toJson() => {
    'callId': id,
    if (groupId != null) 'groupId': groupId,
    'mediaKind': media.name,
    'endReason': endReason,
    'durationMs': durationMs,
  };

  static ChatCallHistory? tryParse(Object? value, {String? expectedGroupId}) {
    if (value is! Map) return null;
    final id = value['callId'], media = value['mediaKind'];
    final group = value['groupId'];
    if (group != expectedGroupId) return null;
    if (group != null &&
        (group is! String ||
            !RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ).hasMatch(group))) {
      return null;
    }
    final reason = value['endReason'], duration = value['durationMs'];
    if (id is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(id) ||
        !['audio', 'video'].contains(media) ||
        !(group != null
                ? ['ended']
                : [
                    'cancelled',
                    'declined',
                    'missed',
                    'failed',
                    'revoked',
                    'hangup',
                  ])
            .contains(reason) ||
        (group != null && duration != null) ||
        (duration != null && (duration is! int || duration < 0))) {
      return null;
    }
    return ChatCallHistory(
      id,
      media == 'audio' ? CallMedia.audio : CallMedia.video,
      reason as String,
      duration as int?,
      groupId: group as String?,
    );
  }
}
