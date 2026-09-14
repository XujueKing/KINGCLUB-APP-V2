import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/voice_capture.dart';

class Device implements VoiceCaptureDevice {
  bool failCancel = false, failStop = false, missingPath = false;
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
    if (failCancel) throw StateError('native cancellation failed');
  }

  @override
  Future<String?> stop() async {
    stops++;
    if (failStop) throw StateError('native stop failed');
    return missingPath ? null : 'voice.m4a';
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class InterruptibleDevice extends Device implements VoiceCaptureInterruptions {
  final events = StreamController<void>.broadcast(sync: true);
  @override
  Stream<void> get interruptions => events.stream;
}

void main() {
  for (final withCallback in [false, true]) {
    test(
      'audio interruption cancels recording and never yields draft: $withCallback',
      () async {
        final device = InterruptibleDevice()
          ..permission.complete(true)
          ..started.complete();
        addTearDown(device.events.close);
        final capture = VoiceCapture(
          device: device,
          allocatePath: () async => 'voice.m4a',
        );
        Future<void>? observed;
        var notices = 0;
        capture.begin(
          onLimit: () {},
          onInterrupted: withCallback
              ? () {
                  notices++;
                  observed = expectLater(
                    capture.finish(cancel: false),
                    throwsStateError,
                  );
                }
              : null,
        );
        await Future<void>.delayed(Duration.zero);
        device.events.add(null);
        await observed;
        await Future<void>.delayed(Duration.zero);
        expect(device.cancels, 1);
        expect(device.stops, 0);
        expect(notices, withCallback ? 1 : 0);
        expect(await capture.finish(cancel: false), isNull);
        await capture.dispose();
        expect(device.events.hasListener, isFalse);
      },
    );
  }
  test(
    'idle or post-release platform events cannot interrupt a later capture',
    () async {
      final device = InterruptibleDevice()
        ..permission.complete(true)
        ..started.complete();
      addTearDown(device.events.close);
      final capture = VoiceCapture(
        device: device,
        allocatePath: () async => 'voice.m4a',
      );
      var notices = 0;
      device.events.add(null);
      capture.begin(onLimit: () {}, onInterrupted: () => notices++);
      await Future<void>.delayed(Duration.zero);
      final ending = capture.finish(cancel: true);
      device.events.add(null);
      await ending;
      expect(notices, 0);
      expect(device.cancels, 1);
      await capture.dispose();
    },
  );
  test('cancel failure immediately releases recorder without waiting for page disposal', () async {
    final device = Device()
      ..permission.complete(true)
      ..started.complete()
      ..failCancel = true;
    final capture = VoiceCapture(
      device: device,
      allocatePath: () async => 'voice.m4a',
    );
    capture.begin(onLimit: () {});
    await Future<void>.delayed(Duration.zero);
    await expectLater(capture.finish(cancel: true), throwsStateError);
    expect(device.disposals, 1);
    expect(capture.begin(onLimit: () {}), isFalse);
    await capture.dispose();
    expect(device.disposals, 1);
  });
  for (final failCancel in [false, true]) {
    test(
      'partial start failure cancels, retires recorder if cancel fails: $failCancel',
      () async {
        final device = Device()
          ..permission.complete(true)
          ..failCancel = failCancel;
        final capture = VoiceCapture(
          device: device,
          allocatePath: () async => 'voice.m4a',
        );
        capture.begin(onLimit: () {});
        await Future<void>.delayed(Duration.zero);
        device.started.completeError(
          StateError('partial native start failure'),
        );
        await expectLater(capture.finish(cancel: false), throwsStateError);
        expect(device.cancels, 1);
        expect(device.stops, 0);
        if (failCancel) expect(capture.begin(onLimit: () {}), isFalse);
        await capture.dispose();
        expect(device.disposals, 1);
      },
    );
  }
  for (final missingPath in [false, true]) {
    test(
      'failed stop or missing output cancels and returns no draft: $missingPath',
      () async {
        final device = Device()
          ..permission.complete(true)
          ..started.complete()
          ..failStop = !missingPath
          ..missingPath = missingPath;
        final capture = VoiceCapture(
          device: device,
          allocatePath: () async => 'voice.m4a',
        );
        capture.begin(onLimit: () {});
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        await expectLater(capture.finish(cancel: false), throwsStateError);
        expect(device.stops, 1);
        expect(device.cancels, 1);
        await capture.dispose();
        expect(device.disposals, 1);
      },
    );
  }
  test(
    'dispose releases device even when cancellation fails and forbids reuse',
    () async {
      final device = Device()
        ..permission.complete(true)
        ..started.complete()
        ..failCancel = true;
      final capture = VoiceCapture(
        device: device,
        allocatePath: () async => 'voice.m4a',
      );
      capture.begin(onLimit: () {});
      await Future<void>.delayed(Duration.zero);
      await expectLater(capture.dispose(), throwsStateError);
      expect(device.disposals, 1);
      expect(capture.begin(onLimit: () {}), isFalse);
    },
  );
  test('concurrent disposal releases the native recorder only once', () async {
    final device = Device();
    final capture = VoiceCapture(
      device: device,
      allocatePath: () async => 'voice.m4a',
    );
    await Future.wait([capture.dispose(), capture.dispose()]);
    expect(device.disposals, 1);
    expect(capture.begin(onLimit: () {}), isFalse);
  });
  test(
    'system denied recording never allocates or returns a sendable draft',
    () async {
      final device = Device()..permission.complete(false);
      var allocations = 0;
      final capture = VoiceCapture(
        device: device,
        allocatePath: () async {
          allocations++;
          return 'voice.m4a';
        },
      );
      capture.begin(onLimit: () {});
      await expectLater(capture.finish(cancel: false), throwsStateError);
      expect(allocations, 0);
      expect(device.starts, 0);
      expect(device.stops, 0);
      await capture.dispose();
    },
  );

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
