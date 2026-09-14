import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import 'messaging_repository.dart';
import 'novorudp_device_binding.dart';
import 'novorudp_device_identity_store.dart';

/// Device registration only. Never opens UDP sockets or changes message routes.
class NovoRudpBindingRuntime {
  static const enabled = bool.fromEnvironment(
    'KINGCLUB_NOVORUDP_DEVICE_BINDING',
  );
  static StreamSubscription<void>? _sessionEvents;
  static Future<void>? _work;
  static NovoRudpDeviceBinding? _binding;
  static int _generation = -1;
  static Stopwatch? _failedAt;

  static void start(MessagingRepository messaging) {
    if (!enabled || !Platform.isAndroid || Abi.current() != Abi.androidArm64) {
      return;
    }
    _sessionEvents ??= SecureSessionStore.changes.stream.listen(
      (_) => _clear(),
    );
    if (_generation != MemberQrMemory.generation) {
      _clear();
      _generation = MemberQrMemory.generation;
    }
    if (_binding != null ||
        _work != null ||
        (_failedAt != null &&
            _failedAt!.elapsed < const Duration(minutes: 5))) {
      return;
    }
    final task = _initialize(messaging, _generation);
    _work = task;
    unawaited(
      task.whenComplete(() {
        if (identical(_work, task)) _work = null;
      }),
    );
  }

  static void _clear() {
    _binding?.dispose();
    _binding = null;
    _work = null;
    _failedAt = null;
    _generation = -1;
  }

  static Future<void> _initialize(
    MessagingRepository messaging,
    int generation,
  ) async {
    NovoRudpDeviceBinding? binding;
    try {
      final library = DynamicLibrary.open('libkingclub_novorudp.so');
      final identity = await NovoRudpDeviceIdentityStore().open(
        account: messaging.account,
        library: library,
      );
      if (generation != MemberQrMemory.generation ||
          generation != _generation) {
        identity.dispose();
        return;
      }
      binding = NovoRudpDeviceBinding(messaging: messaging, identity: identity);
      _binding = binding;
      await binding.ensureRegistered();
      if (generation != MemberQrMemory.generation ||
          !identical(_binding, binding)) {
        binding.dispose();
        return;
      }
      debugPrint('NOVORUDP_DEVICE_BINDING_READY');
    } catch (error) {
      binding?.dispose();
      if (generation == MemberQrMemory.generation &&
          generation == _generation) {
        _binding = null;
        _failedAt = Stopwatch()..start();
        // No member IDs, public keys, device IDs, challenge or credentials.
        debugPrint(
          'NOVORUDP_DEVICE_BINDING_UNAVAILABLE ${error is AuthFailure ? error.code : error.runtimeType}',
        );
      }
    }
  }
}
