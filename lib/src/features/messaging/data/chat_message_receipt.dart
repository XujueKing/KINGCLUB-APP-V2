import 'chat_location.dart';

/// Payload agreement is required before an own message leaves the durable queue,
/// whether acknowledgement arrives from send, catch-up or an older history page.
void validateQueuedMessageReceipt(
  Map<String, dynamic> pending,
  Map<String, dynamic> received,
) {
  if (['recalled', 'hidden'].contains(received['messageType'])) return;
  final kind = pending['messageType'] ?? 'text';
  if ((received['messageType'] ?? 'text') != kind) {
    throw const FormatException('消息回执与发送内容不符');
  }
  final fields = switch (kind) {
    'text' => ['text'],
    'image' => ['imageAssetId'],
    'voice' => ['voiceAssetId', 'voiceDurationMs'],
    'video' => [
      'videoAssetId',
      'videoDurationMs',
      'videoWidth',
      'videoHeight',
      'videoHasAudio',
    ],
    'file' => ['fileAssetId', 'fileName', 'fileSize', 'fileSha256'],
    'location' => <String>[],
    _ => throw const FormatException('消息回执与发送内容不符'),
  };
  if (fields.any((field) => pending[field] != received[field])) {
    throw const FormatException('消息回执与发送内容不符');
  }
  if (kind == 'location' &&
      !ChatLocation.fromJson(
        Map<String, dynamic>.from(pending['location'] as Map),
      ).sameAs(
        ChatLocation.fromJson(
          Map<String, dynamic>.from(received['location'] as Map),
        ),
      )) {
    throw const FormatException('消息回执与发送内容不符');
  }
  if (pending['replyToMessageId'] != null &&
      (received['reply'] is! Map ||
          (received['reply'] as Map)['messageId'] !=
              pending['replyToMessageId'])) {
    throw const FormatException('消息回执与发送内容不符');
  }
}
