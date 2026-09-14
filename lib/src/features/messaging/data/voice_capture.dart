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

abstract interface class VoiceCaptureInterruptions {
  Stream<void> get interruptions;
}

class NativeVoiceCaptureDevice
    implements VoiceCaptureDevice, VoiceCaptureInterruptions {
  final _recorder = AudioRecorder();
  @override
  Stream<void> get interruptions async* {
    var wasRecording = false;
    await for (final state in _recorder.onStateChanged()) {
      if (state == RecordState.record) {
        wasRecording = true;
      } else if (wasRecording) {
        wasRecording = false;
        yield null;
      }
    }
  }

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
  VoiceCapture({required this.device, required this.allocatePath}) {
    final source = device;
    if (source is VoiceCaptureInterruptions) {
      _interruptions = (source as VoiceCaptureInterruptions).interruptions
          .listen(
            (_) => _interrupt(),
            onError: (Object error, StackTrace stack) => _interrupt(),
          );
    }
  }
  final VoiceCaptureDevice device;
  final Future<String> Function() allocatePath;
  final _elapsed = Stopwatch();
  Future<void> _starting = Future.value();
  bool _held = false, _recording = false, _busy = false;
  bool _disposed = false;
  Future<void>? _disposing;
  Future<void>? _releasing;
  Object? _error;
  Timer? _limit;
  StreamSubscription<void>? _interruptions;
  void Function()? _onInterrupted;

  void _interrupt() {
    if (!_busy || !_held || _disposed) return;
    _error = StateError('录音被中断，请重新按住说话');
    _held = false;
    _elapsed.stop();
    _limit?.cancel();
    _onInterrupted?.call();
    // Cleanup also runs without a visible page callback; the UI can await the
    // same finish Future and display the interruption through its normal notice.
    unawaited(finish(cancel: false).then<void>((_) {}, onError: (Object _) {}));
  }

  static VoiceCapture native() => VoiceCapture(
    device: NativeVoiceCaptureDevice(),
    allocatePath: () async => (await VoiceDraftStore.current()).allocate(),
  );

  bool begin({
    required void Function() onLimit,
    void Function()? onInterrupted,
  }) {
    if (_busy || _disposed) return false;
    _busy = true;
    _held = true;
    _error = null;
    _onInterrupted = onInterrupted;
    _starting = () async {
      var startAttempted = false;
      try {
        if (!await device.hasPermission()) {
          throw StateError('请允许麦克风权限后再试');
        }
        if (!_held) return;
        final path = await allocatePath();
        if (!_held) return;
        startAttempted = true;
        await device.start(path);
        _recording = true;
        _elapsed
          ..reset()
          ..start();
        if (_held) _limit = Timer(const Duration(seconds: 60), onLimit);
      } catch (error) {
        _error = error;
        if (startAttempted) await _discardAfterFailure();
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
        if (_recording) await _cancelRecording();
        return null;
      }
      if (_error != null) {
        if (_recording) await _discardAfterFailure();
        if (_error is StateError) throw _error!;
        throw StateError('无法录音，请在系统设置中允许 KINGCLUB 使用麦克风，并检查是否被其他应用占用');
      }
      if (!_recording) return null;
      if (_elapsed.elapsed < const Duration(seconds: 1)) {
        await _cancelRecording();
        throw StateError('说话时间太短');
      }
      String? path;
      try {
        path = await device.stop();
        if (path == null) throw StateError('录音未保存，请重试');
      } catch (_) {
        await _discardAfterFailure();
        rethrow;
      }
      return VoiceDraft(path, _elapsed.elapsed);
    } finally {
      _recording = false;
      _busy = false;
      _onInterrupted = null;
    }
  }

  // A failed start/stop can still leave a platform recorder allocated.
  // If cancel also fails, retire this capture rather than reuse that recorder.
  Future<void> _discardAfterFailure() async {
    try {
      await _cancelRecording();
    } catch (_) {
      // Keep the original recording failure visible to the caller.
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await device.cancel();
    } catch (_) {
      _disposed = true;
      try {
        await _releaseDevice();
      } catch (_) {
        // Never reuse a device whose native cleanup failed.
      }
      rethrow;
    }
  }

  Future<void> _releaseDevice() => _releasing ??= device.dispose();

  Future<void> dispose() {
    _disposed = true;
    return _disposing ??= _dispose();
  }

  Future<void> _dispose() async {
    await _interruptions?.cancel();
    try {
      await finish(cancel: true);
    } finally {
      await _releaseDevice();
    }
  }
}
