import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import 'native_push_registration.dart';

typedef PushSession = Map<String, dynamic>;
typedef PushCall = Future<void> Function(
  PushSession session,
  String id,
  Map<String, dynamic> params,
);

/// Serializes SDK registration and server binding across account changes.
class PushRegistrationRuntime {
  PushRegistrationRuntime({
    required this.readSession,
    required this.register,
    required this.call,
    this.retryDelay = const Duration(seconds: 15),
  });
  final Future<PushSession?> Function() readSession;
  final Future<String> Function() register;
  final PushCall call;
  final Duration retryDelay;
  PushSession? _bound;
  Future<void>? _running;
  Timer? _retry;
  int _generation = 0;
  int _failures = 0;
  bool _closed = false, _foreground = true;

  static PushRegistrationRuntime? configured() {
    const key = String.fromEnvironment('KINGCLUB_OPPO_APP_KEY');
    const secret = String.fromEnvironment('KINGCLUB_OPPO_APP_SECRET');
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        kingclubApiBaseUrl.isEmpty ||
        key.isEmpty ||
        secret.isEmpty) {
      return null;
    }
    final store = SecureSessionStore();
    final client = KingclubSecureClient(kingclubApiBaseUrl);
    return PushRegistrationRuntime(
      readSession: store.readSession,
      register: () =>
          NativePushRegistration().register(appKey: key, appSecret: secret),
      call: (session, id, params) async {
        final response = await client.call(id, params, session: session);
        if ((response['result'] as Map?)?['registered'] !=
            (id == 'K260926000730')) {
          throw const FormatException('Invalid push binding response');
        }
      },
    );
  }

  static bool _same(PushSession? a, PushSession? b) =>
      a != null &&
      b != null &&
      a['sessionId'] == b['sessionId'] &&
      a['apiKeyId'] == b['apiKeyId'] &&
      a['apiKey'] == b['apiKey'] &&
      (a['account'] as Map?)?['userAccount'] ==
          (b['account'] as Map?)?['userAccount'];
  static bool _eligible(PushSession? s) =>
      s != null &&
      (s['account'] as Map?)?['accountStatus'] == 'active' &&
      (s['membership'] as Map?)?['status'] == 'active' &&
      (s['membership'] as Map?)?['registrationStatus'] == 'approved';

  void foreground(bool value) {
    _foreground = value;
    _retry?.cancel();
    if (value) sync();
  }

  void sync() {
    if (_closed) return;
    _generation++;
    _retry?.cancel();
    if (_running != null) return;
    final task = _pump();
    _running = task;
    unawaited(
      task.whenComplete(() {
        _running = null;
      }),
    );
  }

  Future<void> _remove(PushSession old) async {
    try {
      await call(old, 'K260926000731', {});
    } on AuthFailure catch (error) {
      // Revoked/expired sessions are excluded by the server on every delivery.
      if (!{
        'SESSION_EXPIRED',
        'SESSION_REVOKED',
        'SESSION_REQUIRED',
        'PUSH_SESSION_INVALID',
      }.contains(error.code)) {
        rethrow;
      }
    }
  }

  Future<void> _pump() async {
    while (!_closed) {
      final revision = _generation;
      try {
        final current = await readSession();
        if (_closed) return;
        if (revision != _generation) continue;
        if (_bound != null &&
            (!_same(_bound, current) || !_eligible(current))) {
          final old = _bound!;
          await _remove(old);
          _bound = null;
        }
        if (revision != _generation) continue;
        if (!_foreground || !_eligible(current)) return;
        final token = await register();
        if (_closed) return;
        if (revision != _generation ||
            !_foreground ||
            !_same(current, await readSession())) {
          continue;
        }
        // A timeout can occur after the server commits. Remember the attempted
        // binding so a subsequent logout still unregisters that session.
        _bound = current;
        await call(current!, 'K260926000730', {
          'provider': 'oppo',
          'packageName': 'com.lingmei.kingclub',
          'token': token,
        });
        _bound = current;
        _failures = 0;
        if (_closed) return;
        if (revision != _generation) continue;
        return;
      } catch (_) {
        if (_closed) return;
        if (revision != _generation) continue;
        if (_foreground) {
          final multiplier = 1 << _failures.clamp(0, 4);
          _failures++;
          _retry = Timer(retryDelay * multiplier, sync);
        }
        return;
      }
    }
  }

  void close() {
    _closed = true;
    _generation++;
    _retry?.cancel();
  }
}
