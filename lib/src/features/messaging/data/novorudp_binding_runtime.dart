import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import 'messaging_repository.dart';
import 'member_relay_runtime.dart';
import 'member_relay_text.dart';
import 'chat_history_store.dart';
import 'novorudp_device_binding.dart';
import 'novorudp_device_identity_store.dart';

/// Registers the device and optionally maintains an explicitly configured relay.
/// Never changes message routes without a separate member-authorized channel.
class NovoRudpBindingRuntime {
  static const relayUrl = String.fromEnvironment('KINGCLUB_NOVORUDP_RELAY_URL');
  static const relayPeer = String.fromEnvironment(
    'KINGCLUB_NOVORUDP_RELAY_PEER',
  );
  static bool get relayConfigured =>
      relayUrl.isNotEmpty && relayPeer.isNotEmpty;
  static const enabled = bool.fromEnvironment(
    'KINGCLUB_NOVORUDP_DEVICE_BINDING',
  );
  static StreamSubscription<void>? _sessionEvents;
  static Future<void>? _work;
  static NovoRudpDeviceBinding? _binding;
  static MemberRelayRuntime? _relay;
  static MemberRelayRuntime? get relay => _relay;
  static MemberRelayText? _text;
  static StreamSubscription<String>? _textEvents;
  static final _textChanges =
      StreamController<({String account, String peer})>.broadcast();
  static Stream<String> textChanges(String account) => _textChanges.stream
      .where((event) => event.account == account)
      .map((event) => event.peer);

  static Future<List<Map<String, dynamic>>> Function() textReader(
    String account,
    String peer,
  ) {
    final generation = MemberQrMemory.generation;
    return () async {
      if (generation != MemberQrMemory.generation) {
        throw StateError('Chat account changed');
      }
      final history = await ChatHistoryStore.open(account);
      if (generation != MemberQrMemory.generation) {
        throw StateError('Chat account changed');
      }
      final rows = await history.nearbyMemberMessages(peer);
      if (generation != MemberQrMemory.generation) {
        throw StateError('Chat account changed');
      }
      return rows;
    };
  }

  static int _generation = -1;

  static Future<void> Function(List<String>) textReadMarker(
    String account,
    String peer,
  ) {
    final generation = MemberQrMemory.generation;
    return (ids) async {
      if (generation != MemberQrMemory.generation) return;
      final history = await ChatHistoryStore.open(account);
      if (generation != MemberQrMemory.generation) return;
      final changed = await history.markNearbyMemberRead(peer, ids);
      if (generation == MemberQrMemory.generation && changed > 0) {
        _textChanges.add((account: account, peer: peer));
        final text = _text;
        if (text != null && text.history.account == account) {
          unawaited(text.flushReadReceipts(peer));
        }
      }
    };
  }

  static Future<bool> Function(String, String) textSender(
    String account,
    String peer,
  ) {
    final generation = MemberQrMemory.generation;
    return (text, id) async {
      final channel = _text;
      final binding = _binding;
      if (generation != MemberQrMemory.generation ||
          channel == null ||
          binding == null ||
          binding.messaging.account != account ||
          _relay?.connection == null) {
        return false;
      }
      final keys = await binding
          .directory(peer)
          .timeout(const Duration(seconds: 3));
      if (generation != MemberQrMemory.generation ||
          !identical(channel, _text)) {
        return false;
      }
      // The current directory is authorization; cached keys never grant access.
      // Try a bounded set, retaining the original ID on every attempt.
      for (final key in keys.take(2)) {
        try {
          await channel
              .sendText(
                peer: peer,
                bindingId: key.bindingId,
                text: text,
                messageId: id,
              )
              .timeout(const Duration(seconds: 3));
          return generation == MemberQrMemory.generation &&
              identical(channel, _text);
        } catch (_) {
          if (generation != MemberQrMemory.generation ||
              !identical(channel, _text)) {
            return false;
          }
        }
      }
      return false;
    };
  }

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
    unawaited(_textEvents?.cancel());
    _textEvents = null;
    unawaited(_text?.close());
    _text = null;
    _relay?.close();
    _relay = null;
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
    MemberRelayRuntime? runtime;
    MemberRelayText? text;
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
      if (relayUrl.isNotEmpty && relayPeer.isNotEmpty) {
        final history = await ChatHistoryStore.open(messaging.account);
        if (generation != MemberQrMemory.generation ||
            !identical(_binding, binding)) {
          return;
        }
        runtime = MemberRelayRuntime(
          binding: binding,
          endpoint: Uri.parse(relayUrl),
          expectedRelay: relayPeer,
        );
        text = MemberRelayText(runtime: runtime, history: history);
        _text = text;
        _textEvents = text.changes.listen((peer) {
          if (generation == MemberQrMemory.generation &&
              identical(_text, text)) {
            _textChanges.add((account: messaging.account, peer: peer));
          }
        });
        _relay = runtime;
        runtime.start();
      }
    } catch (error) {
      unawaited(text?.close());
      runtime?.close();
      if (text != null && identical(_text, text)) {
        unawaited(_textEvents?.cancel());
        _textEvents = null;
        _text = null;
        _relay = null;
      }
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
