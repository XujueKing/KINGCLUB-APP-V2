import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/member_relay_runtime.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_device_binding.dart';
import 'package:kingclub/src/features/messaging/data/novorudp_secure_session.dart';

class _NetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _NetworkBinding();
  final env = Platform.environment;
  final enabled = [
    'NOVORUDP_NATIVE_LIBRARY',
    'SUPERVM_TEST_RELAY_URL',
    'SUPERVM_TEST_RELAY_PEER',
    'SUPERVM_TEST_RELAY_CERT',
  ].every(env.containsKey);
  test(
    'real relay foreground reconnect and cancelled directory lookup',
    () async {
      final random = Random.secure();
      final identity = NovoRudpSecureSession.fromSeed(
        library: DynamicLibrary.open(env['NOVORUDP_NATIVE_LIBRARY']!),
        seed: Uint8List.fromList(List.generate(32, (_) => random.nextInt(256))),
      );
      addTearDown(identity.dispose);
      Completer<void>? hold;
      var reads = 0;
      final binding = NovoRudpDeviceBinding(
        identity: identity,
        messaging: MessagingRepository(
          account: 'runtime-member',
          call: (api, params) async {
            expect(api, 'K260915000672');
            expect(params['peer'], 'runtime-member');
            reads++;
            await hold?.future;
            return {
              'cacheSeconds': 0,
              'keys': [
                {
                  'bindingId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                  'peerId': identity.peerId,
                  'publicKey': identity.peerId.split(':').last,
                },
              ],
            };
          },
        ),
      );
      final runtime = MemberRelayRuntime(
        binding: binding,
        endpoint: Uri.parse(env['SUPERVM_TEST_RELAY_URL']!),
        expectedRelay: env['SUPERVM_TEST_RELAY_PEER']!,
        securityContext: SecurityContext(withTrustedRoots: false)
          ..setTrustedCertificates(env['SUPERVM_TEST_RELAY_CERT']!),
      );
      addTearDown(runtime.close);
      final firstReady = runtime.connections.firstWhere(
        (value) => value != null,
      );
      runtime.start();
      runtime.didChangeAppLifecycleState(AppLifecycleState.resumed);
      final first = (await firstReady.timeout(const Duration(seconds: 5)))!;
      final ack = first.messages.firstWhere(
        (event) => event['kind'] == 'heartbeat_ack',
      );
      first.heartbeat();
      await ack.timeout(const Duration(seconds: 2));
      final paused = runtime.connections.firstWhere((value) => value == null);
      runtime.didChangeAppLifecycleState(AppLifecycleState.paused);
      await paused;
      expect(runtime.connection, isNull);
      expect(first.heartbeat, throwsStateError);
      final secondReady = runtime.connections.firstWhere(
        (value) => value != null,
      );
      runtime.didChangeAppLifecycleState(AppLifecycleState.resumed);
      final second = (await secondReady.timeout(const Duration(seconds: 5)))!;
      expect(identical(first, second), isFalse);
      expect(reads, 2);
      runtime.didChangeAppLifecycleState(AppLifecycleState.paused);
      hold = Completer<void>();
      runtime.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(reads, 3);
      final lateConnections = <Object>[];
      final subscription = runtime.connections.listen((value) {
        if (value != null) lateConnections.add(value);
      });
      addTearDown(subscription.cancel);
      final done = runtime.connections.drain<void>();
      runtime.close();
    hold.complete();
      await done;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(lateConnections, isEmpty);
      expect(runtime.connection, isNull);
      expect(second.heartbeat, throwsStateError);
    },
    skip: !enabled,
  );
}
