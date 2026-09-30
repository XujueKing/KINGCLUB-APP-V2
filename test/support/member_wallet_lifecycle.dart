import 'dart:ui' show AppLifecycleState;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Follow engine transitions and draw the inactive frame before pausing frames.
Future<void> walletLifecycle(
  WidgetTester tester,
  AppLifecycleState state,
) async {
  Future<void> send(AppLifecycleState next) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/lifecycle',
      const StringCodec().encodeMessage(next.toString()),
      (_) {},
    );
  }

  if (state == AppLifecycleState.paused &&
      tester.binding.lifecycleState == AppLifecycleState.resumed) {
    await send(AppLifecycleState.inactive);
    await tester.pump();
  }
  await send(state);
}
