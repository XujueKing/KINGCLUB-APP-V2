import 'dart:io';

import '../../../core/session/member_qr_memory.dart';
import 'messaging_repository.dart';
import 'voice_capture.dart';
import 'voice_draft_store.dart';
import 'chat_voice_uploader.dart';

class VoiceDraftTranscriber {
  VoiceDraftTranscriber(this.repository);
  final MessagingRepository repository;
  ChatVoiceUploader? _upload;
  bool _disposed = false, _busy = false;
  Future<String> transcribe(VoiceDraft draft) async {
    if (_disposed || _busy) throw StateError('录音正在处理或会话已关闭');
    _busy = true;
    final generation = MemberQrMemory.generation;
    void check() {
      if (_disposed || generation != MemberQrMemory.generation) {
        throw StateError('登录状态已变化');
      }
    }

    try {
      final store = await VoiceDraftStore.current();
      check();
      if (!store.owns(draft.path)) throw StateError('录音不属于当前账号');
      final file = File(draft.path);
      final length = await file.length();
      check();
      if (length < 1 || length > 2 * 1024 * 1024) throw StateError('录音文件大小无效');
      final upload = await ChatVoiceUploader.open(repository);
      _upload = upload;
      check();
      final bytes = await file.readAsBytes();
      check();
      final voice = await upload.upload(bytes);
      check();
      final result = await repository.call('K260915000674', {
        'assetId': voice.assetId,
      });
      check();
      final text = result['text'];
      if (result['assetId'] != voice.assetId ||
          text is! String ||
          text.length > 4000 ||
          !['recognized', 'no-speech'].contains(result['status']) ||
          (result['status'] == 'recognized') != text.trim().isNotEmpty) {
        throw StateError('识别结果无效');
      }
      // Keep the original recording and upload journal for explicit retries.
      return text.trim();
    } finally {
      _upload?.dispose();
      _upload = null;
      _busy = false;
    }
  }

  void dispose() {
    _disposed = true;
    _upload?.dispose();
  }
}
