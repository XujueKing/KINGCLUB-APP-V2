import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'voice_draft_store.dart';

import 'package:record/record.dart';

class VoiceDraft {
  const VoiceDraft(this.path, this.duration);
  final String path;
  final Duration duration;
}

abstract interface class VoiceCaptureDevice {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class NativeVoiceCaptureDevice implements VoiceCaptureDevice {
  final _recorder = AudioRecorder();
  @override
  Future<bool> hasPermission() async {
    if (!await _recorder.hasPermission()) return false;
    // OEM privacy controls can deny AppOps while runtime permission is granted.
    if (Platform.isAndroid) {
      return await const MethodChannel('kingclub/microphone')
              .invokeMethod<bool>('isRecordingAllowed') ==
          true;
    }
    return true;
  }

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 24000,
      bitRate: 48000,
      numChannels: 1,
      noiseSuppress: true,
      echoCancel: true,
      autoGain: true,
      androidConfig: AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceCommunication,
      ),
    ),
    path: path,
  );
  @override
  Future<String?> stop() => _recorder.stop();
  @override
  Future<void> cancel() => _recorder.cancel();
  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Serializes permission/start/stop so releasing during an OS permission dialog
/// can never leave a recorder running in the background.
class VoiceCapture {
  VoiceCapture({required this.device, required this.allocatePath});
  final VoiceCaptureDevice device;
  final Future<String> Function() allocatePath;
  final _elapsed = Stopwatch();
  Future<void> _starting = Future.value();
  bool _held = false, _recording = false, _busy = false;
  bool _disposed = false;
  Future<void>? _disposing;
  Object? _error;
  Timer? _limit;

  static VoiceCapture native() => VoiceCapture(
    device: NativeVoiceCaptureDevice(),
    allocatePath: () async => (await VoiceDraftStore.current()).allocate(),
  );

  bool begin({required void Function() onLimit}) {
    if (_busy || _disposed) return false;
    _busy = true;
    _held = true;
    _error = null;
    _starting = () async {
      try {
        if (!await device.hasPermission()) {
          throw StateError('请允许麦克风权限后再试');
        }
        if (!_held) return;
        final path = await allocatePath();
        if (!_held) return;
        await device.start(path);
        _recording = true;
        _elapsed
          ..reset()
          ..start();
        if (_held) _limit = Timer(const Duration(seconds: 60), onLimit);
      } catch (error) {
        _error = error;
      }
    }();
    return true;
  }

  Future<VoiceDraft?>? _finishing;
  Future<VoiceDraft?> finish({required bool cancel}) {
    return _finishing ??= _finish(cancel: cancel)
        .whenComplete(() => _finishing = null);
  }

  Future<VoiceDraft?> _finish({required bool cancel}) async {
    if (!_busy) return null;
    _held = false;
    _limit?.cancel();
    await _starting;
    _elapsed.stop();
    try {
      if (cancel) {
        if (_recording) await device.cancel();
        return null;
      }
      if (_error != null) {
        throw StateError('无法录音，请在系统设置中允许 KINGCLUB 使用麦克风，并检查是否被其他应用占用');
      }
      if (!_recording) return null;
      if (_elapsed.elapsed < const Duration(seconds: 1)) {
        await device.cancel();
        throw StateError('说话时间太短');
      }
      final path = await device.stop();
      if (path == null) throw StateError('录音未保存，请重试');
      return VoiceDraft(path, _elapsed.elapsed);
    } finally {
      _recording = false;
      _busy = false;
    }
  }

  Future<void> dispose() {
    _disposed = true;
    return _disposing ??= _dispose();
  }

  Future<void> _dispose() async {
    try {
      await finish(cancel: true);
    } finally {
      await device.dispose();
    }
  }
}
