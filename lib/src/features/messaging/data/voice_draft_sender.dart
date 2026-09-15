import 'dart:io';

import '../../../core/session/member_qr_memory.dart';
import 'chat_session_controller.dart';
import 'messaging_repository.dart';
import 'chat_voice_uploader.dart';
import 'voice_capture.dart';
import 'voice_draft_store.dart';

/// Keep local audio until the server asset is durably queued for this chat.
class VoiceDraftSender {
  VoiceDraftSender({
    Future<VoiceDraftStore> Function()? currentStore,
    Future<ChatVoiceUploader> Function(MessagingRepository)? openUploader,
  }) : _currentStore = currentStore ?? VoiceDraftStore.current,
       _openUploader = openUploader ?? ChatVoiceUploader.open;
  final Future<VoiceDraftStore> Function() _currentStore;
  final Future<ChatVoiceUploader> Function(MessagingRepository) _openUploader;
  final Set<String> _sending = {};
  final Set<ChatVoiceUploader> _uploads = {};
  bool _disposed = false;

  Future<void> send(ChatSessionController chat, VoiceDraft draft) async {
    if (_disposed) throw StateError('会话已关闭');
    if (!_sending.add(draft.path)) throw StateError('这条录音正在发送');
    final generation = MemberQrMemory.generation;
    ChatVoiceUploader? uploader;
    var queued = false;
    try {
      final store = await _currentStore();
      if (store.account != chat.messaging.account) throw StateError('录音账号已变化');
      if (!store.owns(draft.path)) throw StateError('录音不属于当前账号');
      final file = File(draft.path);
      if (await file.length() > 2 * 1024 * 1024) throw StateError('录音须小于2MB');
      uploader = await _openUploader(chat.messaging);
      _uploads.add(uploader);
      if (_disposed || generation != MemberQrMemory.generation) {
        throw StateError('登录状态已变化');
      }
      final voice = await uploader.upload(await file.readAsBytes());
      if (_disposed || generation != MemberQrMemory.generation) {
        throw StateError('登录状态已变化');
      }
      try {
        await chat.sendVoice(
          voice.assetId,
          voice.durationMs,
          onQueued: () => queued = true,
          clientMessageId: store.messageId(draft.path),
        );
      } finally {
        if (queued) {
          // Once the durable queue owns retries, cleanup failures must not invite
          // a second message with a fresh identifier.
          try {
            await uploader.acknowledgeQueued(voice);
          } catch (_) {}
          try {
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
      }
      if (!queued) throw StateError('会话已关闭，录音已保留');
    } catch (_) {
      if (!queued) rethrow;
    } finally {
      if (uploader != null) {
        _uploads.remove(uploader);
        uploader.dispose();
      }
      _sending.remove(draft.path);
    }
  }

  void dispose() {
    _disposed = true;
    for (final upload in _uploads) {
      upload.dispose();
    }
    _uploads.clear();
  }
}
