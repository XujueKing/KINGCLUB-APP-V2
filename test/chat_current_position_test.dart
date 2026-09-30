import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kingclub/src/features/messaging/data/chat_current_position.dart';

Position fix(DateTime timestamp, double accuracy, {bool mocked = false}) =>
    Position(
      longitude: 113,
      latitude: 28,
      timestamp: timestamp,
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: mocked,
    );

class CoarsePlatform extends GeolocatorPlatform {
  int subscriptions = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      LocationAccuracyStatus.reduced;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    subscriptions++;
    return const Stream.empty();
  }
}

void main() {
  test('software-simulated positions are never presented as current physical location', () async {
    final now = DateTime.utc(2026, 10, 1);
    final real = fix(now, 18);
    expect(
      await ChatCurrentPosition.selectFix(
        Stream.fromIterable([fix(now, 1, mocked: true), real]),
        clock: () => now,
      ),
      same(real),
    );
  });
  test('rejects stale and kilometre-wide fixes while waiting for a new precise fix', () async {
    final now = DateTime.utc(2026, 10, 1);
    final precise = fix(now, 12);
    final result = await ChatCurrentPosition.selectFix(
      Stream.fromIterable([
        fix(now.subtract(const Duration(minutes: 5)), 5),
        fix(now, 900),
        fix(now, 80),
        precise,
      ]),
      clock: () => now,
    );
    expect(result, same(precise));
  });
  test(
    'timeout returns the best usable sample and stops location subscription',
    () async {
      final now = DateTime.utc(2026, 10, 1);
      var cancelled = false;
      final source = StreamController<Position>(
        onCancel: () => cancelled = true,
      );
      final pending = ChatCurrentPosition.selectFix(
        source.stream,
        timeout: const Duration(milliseconds: 20),
        clock: () => now,
      );
      source.add(fix(now, 95));
      source.add(fix(now, 60));
      expect((await pending).accuracy, 60);
      expect(cancelled, isTrue);
      await source.close();
    },
  );
  test(
    'rejects missing accuracy, future timestamps and poor results',
    () async {
      final now = DateTime.utc(2026, 10, 1);
      await expectLater(
        ChatCurrentPosition.selectFix(
          Stream.fromIterable([
            fix(now, 0),
            fix(now, double.nan),
            fix(now, -1),
            fix(now, 1500),
            fix(now.add(const Duration(minutes: 1)), 10),
          ]),
          clock: () => now,
        ),
        throwsStateError,
      );
    },
  );
  test('a fix that becomes stale while waiting is not returned', () async {
    final now = DateTime.utc(2026, 10, 1);
    var current = now;
    final source = StreamController<Position>();
    final pending = ChatCurrentPosition.selectFix(
      source.stream,
      timeout: const Duration(milliseconds: 20),
      clock: () => current,
    );
    source.add(fix(now, 65));
    await Future<void>.delayed(Duration.zero);
    current = now.add(const Duration(minutes: 1));
    await expectLater(pending, throwsStateError);
    await source.close();
  });
  test('approximate permission gives an explicit setting prompt without collecting a fix', () async {
    final original = GeolocatorPlatform.instance;
    final platform = CoarsePlatform();
    GeolocatorPlatform.instance = platform;
    addTearDown(() => GeolocatorPlatform.instance = original);
    await expectLater(
      const ChatCurrentPosition().current(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'setting prompt',
          contains('精确位置'),
        ),
      ),
    );
    expect(platform.subscriptions, 0);
  });
}
