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
  Future<void> send(String text, {VoidCallback? onQueued});
  Future<void> sendImage(String assetId, {VoidCallback? onQueued});
  Future<void> sendVoice(
    String assetId,
    int durationMs, {
    VoidCallback? onQueued,
  });
  Future<void> loadOlder();
  Future<void> markVisibleRead(int sequence);
  void resetVisibleHistory();
}
