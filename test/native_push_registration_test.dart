import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/native_push_registration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kingclub/push-registration');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'registration returns token only after a matching native success',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'register');
        expect(call.arguments, {
          'appKey': 'fixture-key',
          'appSecret': 'fixture-secret',
        });
        return {'provider': 'oppo', 'token': 'fixture-token'};
      });
      expect(
        await NativePushRegistration().register(
          appKey: 'fixture-key',
          appSecret: 'fixture-secret',
        ),
        'fixture-token',
      );
    },
  );
  test('invalid native reply is not accepted as a push token', () async {
    for (final reply in [
      null,
      {'provider': 'other', 'token': 'x'},
      {'provider': 'oppo', 'token': ''},
    ]) {
      messenger.setMockMethodCallHandler(channel, (_) async => reply);
      await expectLater(
        NativePushRegistration().register(appKey: 'key', appSecret: 'secret'),
        throwsFormatException,
      );
    }
  });
  test(
    'native timeout remains a failure instead of fake registration',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'PUSH_TIMEOUT'),
      );
      await expectLater(
        NativePushRegistration().register(appKey: 'key', appSecret: 'secret'),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
