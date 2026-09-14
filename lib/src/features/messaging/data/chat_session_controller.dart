import 'chat_video.dart';
import 'chat_location.dart';

import 'package:flutter/foundation.dart';

import 'messaging_repository.dart';

/// Shared native conversation presentation contract; transport remains domain-specific.
abstract class ChatSessionController extends ChangeNotifier {
  MessagingRepository get messaging;
  String? get conversationId;
  String? get error;
  List<Map<String, dynamic>> get messages;
  Map<String, dynamic> get settings;
  bool get hasOlder;
  Future<void> initialize();
  Future<void> synchronize();
  Future<void> retryQueued();
  Future<void> retry(String id);
  bool get canReply => false;
  Future<void> send(
    String text, {
    VoidCallback? onQueued,
    String? replyToMessageId,
  });
  Future<void> sendImage(String assetId, {VoidCallback? onQueued});
  Future<void> sendFile(
    String assetId,
    String fileName,
    int fileSize,
    String fileSha256, {
    VoidCallback? onQueued,
    String? clientMessageId,
  });
  Future<void> sendVideo(ChatVideo video, {VoidCallback? onQueued}) =>
      Future.error(UnsupportedError('视频发送尚未接通'));
  Future<void> sendVoice(
    String assetId,
    int durationMs, {
    VoidCallback? onQueued,
  });
  Future<void> sendLocation(ChatLocation location, {VoidCallback? onQueued});
  Future<void> loadOlder();
  Future<void> markVisibleRead(int sequence);
  bool canHideMessage(String messageId) => false;
  Future<void> hideMessage(String messageId) =>
      Future.error(UnsupportedError('删除尚未接通'));
  Future<void> recall(String messageId) =>
      Future.error(UnsupportedError('撤回尚未接通'));
  bool canRecall(String messageId) {
    final now = DateTime.now().toUtc();
    return messages.any((message) {
      final created = DateTime.tryParse(
        message['createdDate'] as String? ?? '',
      );
      final age = created == null ? null : now.difference(created.toUtc());
      return message['messageId'] == messageId &&
          message['sender'] == messaging.account &&
          message['status'] == 'sent' &&
          [
            null,
            'text',
            'image',
            'voice',
            'video',
            'file',
            'location',
          ].contains(message['messageType']) &&
          age != null &&
          !age.isNegative &&
          age <= const Duration(minutes: 2);
    });
  }

  void resetVisibleHistory();
}
