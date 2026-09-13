import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/voice_capture.dart';

class Device implements VoiceCaptureDevice {
  final permission = Completer<bool>();
  final started = Completer<void>();
  int starts = 0, cancels = 0, stops = 0, disposals = 0;
  @override
  Future<bool> hasPermission() => permission.future;
  @override
  Future<void> start(String path) async {
    starts++;
    await started.future;
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Future<String?> stop() async {
    stops++;
    return 'voice.m4a';
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

void main() {
  test(
    'release during permission never starts recording after permission returns',
    () async {
      final device = Device();
      final capture = VoiceCapture(
        device: device,
        allocatePath: () async => 'voice.m4a',
      );
      capture.begin(onLimit: () {});
      final ending = capture.finish(cancel: false);
      device.permission.complete(true);
      expect(await ending, isNull);
      expect(device.starts, 0);
      await capture.dispose();
    },
  );
  test(
    'cancel and dispose while native start is pending cancel exactly once',
    () async {
      final device = Device()..permission.complete(true);
      final capture = VoiceCapture(
        device: device,
        allocatePath: () async => 'voice.m4a',
      );
      capture.begin(onLimit: () {});
      await Future<void>.delayed(Duration.zero);
      expect(device.starts, 1);
      final ending = capture.finish(cancel: true);
      final disposing = capture.dispose();
      device.started.complete();
      expect(await ending, isNull);
      await disposing;
      expect(device.cancels, 1);
      expect(device.stops, 0);
      expect(device.disposals, 1);
    },
  );
  test(
    'short recording is deleted and never returned as a valid draft',
    () async {
      final device = Device()
        ..permission.complete(true)
        ..started.complete();
      final capture = VoiceCapture(
        device: device,
        allocatePath: () async => 'voice.m4a',
      );
      expect(capture.begin(onLimit: () {}), isTrue);
      expect(capture.begin(onLimit: () {}), isFalse);
      await Future<void>.delayed(Duration.zero);
      await expectLater(capture.finish(cancel: false), throwsStateError);
      expect(device.cancels, 1);
      expect(device.stops, 0);
      await capture.dispose();
    },
  );

  test(
    'completed recording returns the real recorder path after minimum duration',
    () async {
      final device = Device()
        ..permission.complete(true)
        ..started.complete();
      final capture = VoiceCapture(
        device: device,
        allocatePath: () async => 'voice.m4a',
      );
      capture.begin(onLimit: () {});
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final draft = await capture.finish(cancel: false);
      expect(draft!.path, 'voice.m4a');
      expect(draft.duration, greaterThanOrEqualTo(const Duration(seconds: 1)));
      expect(device.stops, 1);
      expect(device.cancels, 0);
      await capture.dispose();
    },
  );
}
