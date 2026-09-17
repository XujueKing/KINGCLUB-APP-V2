import 'dart:async';

import 'package:flutter/foundation.dart';

/// Composer completion means durable local ownership, not remote delivery.
/// Controllers continue their send future and expose delivery errors in rows.
Future<void> waitForChatQueue(
  Future<void> Function(VoidCallback onQueued) send,
) {
  final queued = Completer<void>();
  void accepted() {
    if (!queued.isCompleted) queued.complete();
  }

  void failed(Object error, StackTrace stack) {
    if (!queued.isCompleted) queued.completeError(error, stack);
  }

  Future<void>.sync(() => send(accepted)).then<void>((_) {
    if (!queued.isCompleted) {
      queued.completeError(StateError('Message was not queued'));
    }
  }, onError: failed);
  return queued.future;
}
