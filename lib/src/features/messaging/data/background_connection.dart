import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import 'background_notifications.dart';

class BackgroundConnection {
  static const channel = MethodChannel('kingclub/connection-service');
  static Future<bool> invoke(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    try {
      return await channel.invokeMethod<bool>(method, args) == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// Runs in a service-owned engine: it never renders pages or opens a microphone.
Future<void> runBackgroundMessageReceiver() async {
  WidgetsFlutterBinding.ensureInitialized();
  const control = MethodChannel('kingclub/receiver-control');
  final notifications = BackgroundNotifications();
  final realtime = KingclubRealtime.shared;
  realtime.foreground(false);
  String? activeSession;
  var active = false;
  Future<void> queue = Future.value();
  Future<void> sync() async {
    final session = await SecureSessionStore().readSession();
    final id = session?['sessionId'] as String?;
    if (id == null) {
      realtime.stop();
      notifications.reset();
      await control.invokeMethod<void>('stop');
      return;
    }
    final background = await control.invokeMethod<bool>('state') == true;
    if (background != active) {
      debugPrint('ChatReceiver: background=$background active=$active');
    }
    if (active && (!background || activeSession != id)) {
      realtime.stop();
      notifications.foreground(true);
      if (activeSession != id) notifications.reset();
      active = false;
    }
    activeSession = id;
    if (!background) return;
    if (!active) {
      active = true;
      notifications.foreground(false);
      await realtime.start();
    }
    // Reconcile ringing/ended invitations even when an event was lost.
    notifications.notify({'eventType': 'receiver.checkCalls'});
  }

  void schedule() {
    queue = queue.then((_) => sync()).catchError((Object error) {
      debugPrint('ChatReceiver: sync failed ${error.runtimeType}');
    });
  }

  realtime.events.listen((event) {
    if (active) notifications.notify(event);
  });
  control.setMethodCallHandler((call) async {
    if (call.method == 'changed') schedule();
  });
  Timer.periodic(const Duration(seconds: 20), (_) => schedule());
  schedule();
}
