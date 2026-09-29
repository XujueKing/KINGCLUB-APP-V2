import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import 'native_system_calls.dart';
import 'push_registration_runtime.dart';

/// Separate binding: rotating a PushKit token must not delete ordinary APNs.
PushRegistrationRuntime createVoipRegistration(NativeSystemCalls native) {
  final store = SecureSessionStore();
  final client = KingclubSecureClient(kingclubApiBaseUrl);
  var provider = 'apns_voip_sandbox';
  return PushRegistrationRuntime(
    readSession: store.readSession,
    registrationProvider: () => provider,
    unregisterProvider: () => provider,
    sessionUnavailable: native.unbind,
    register: () async {
      final session = await store.readSession();
      final account = (session?['account'] as Map?)?['userAccount'];
      if (account is! String) throw StateError('No authenticated call account');
      await native.bind(account);
      for (var attempt = 0; attempt < 20; attempt++) {
        final registration = await native.registration();
        if (registration != null) {
          provider = registration.provider;
          return registration.token;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      throw StateError('PushKit token unavailable');
    },
    call: (session, id, params) async {
      final response = await client.call(id, params, session: session);
      if ((response['result'] as Map?)?['registered'] !=
          (id == 'K260926000730')) {
        throw const FormatException('Invalid PushKit binding response');
      }
    },
  );
}
