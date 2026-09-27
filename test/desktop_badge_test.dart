import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/desktop_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kingclub/local-notifications');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'unread replacement, read clear and bounds use documented count',
    () async {
      final counts = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'badge');
            counts.add((call.arguments as Map)['count'] as int);
            return true;
          });
      for (final count in [8, 3, 0, -1, 20000]) {
        expect(await DesktopBadge.update(count), true);
      }
      expect(counts, [8, 3, 0, 0, 9999]);
    },
  );
  test(
    'unsupported device and denied permission are not reported as success',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => false);
      expect(await DesktopBadge.update(3), false);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'DENIED');
          });
      expect(await DesktopBadge.update(3), false);
    },
  );
}
