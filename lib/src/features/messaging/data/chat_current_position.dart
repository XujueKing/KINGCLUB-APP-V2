import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// A short, foreground-only fix; never accept a coarse or stale first sample.
class ChatCurrentPosition {
  const ChatCurrentPosition();

  Future<Position> current() async {
    await ensurePermission();
    return selectFix(
      Geolocator.getPositionStream(
        locationSettings: defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
                forceLocationManager: true,
                accuracy: LocationAccuracy.best,
                distanceFilter: 0,
                intervalDuration: const Duration(seconds: 1),
              )
            : const LocationSettings(accuracy: LocationAccuracy.best),
      ),
    );
  }

  /// Shared by the GPS stream and the map's own user-location source.
  static Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('请先开启手机定位服务');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('未获得定位权限，请在定位权限设置中允许定位');
    }
    if (await Geolocator.getLocationAccuracy() ==
        LocationAccuracyStatus.reduced) {
      throw StateError('当前仅允许模糊定位，请在定位权限设置中开启精确位置');
    }
  }

  @visibleForTesting
  static Future<Position> selectFix(
    Stream<Position> samples, {
    Duration timeout = const Duration(seconds: 20),
    DateTime Function()? clock,
  }) async {
    final now = clock ?? DateTime.now;
    bool usable(Position sample) {
      final age = now().difference(sample.timestamp);
      return sample.latitude.isFinite &&
          !sample.isMocked &&
          sample.longitude.isFinite &&
          sample.latitude.abs() <= 90 &&
          sample.longitude.abs() <= 180 &&
          sample.accuracy.isFinite &&
          sample.accuracy > 0 &&
          sample.accuracy <= 100 &&
          age >= const Duration(seconds: -5) &&
          age <= const Duration(seconds: 30);
    }

    final ready = Completer<Position?>();
    Position? best;
    final subscription = samples.listen(
      (sample) {
        if (!usable(sample) || ready.isCompleted) return;
        if (best == null || sample.accuracy < best!.accuracy) best = sample;
        if (sample.accuracy <= 50) ready.complete(sample);
      },
      onError: (Object error, StackTrace trace) {
        if (!ready.isCompleted) ready.completeError(error, trace);
      },
      onDone: () {
        if (!ready.isCompleted) ready.complete(best);
      },
    );
    Position? selected;
    try {
      selected = await ready.future.timeout(timeout, onTimeout: () => best);
    } finally {
      await subscription.cancel();
    }
    if (selected == null || !usable(selected)) {
      throw StateError('当前定位精度不足，请移至窗边或室外重试，也可搜索详细地址');
    }
    return selected;
  }
}
