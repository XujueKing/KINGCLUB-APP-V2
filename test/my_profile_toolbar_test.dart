import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';

void main() {
  testWidgets('我的主页左上工具栏保持旧版图标与点击区比例', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var qrOpened = false;
    var settingsOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(393, 852)),
          child: Scaffold(
            body: MyProfilePage(
              onOpenPersonalQr: () => qrOpened = true,
              onOpenSettings: () => settingsOpened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final qrTap = tester.getRect(find.byKey(const ValueKey('my-profile-qr')));
    final settingsTap = tester.getRect(
      find.byKey(const ValueKey('my-profile-settings')),
    );
    final qrImage = tester.getRect(
      find.byKey(const ValueKey('my-profile-qr-image')),
    );
    final settingsImage = tester.getRect(
      find.byKey(const ValueKey('my-profile-settings-image')),
    );
    final toolbar = tester.getRect(
      find.byKey(const ValueKey('my-profile-top-tools')),
    );

    const scale = 393 / 750;
    expect(qrImage.width, closeTo(40 * scale, .01));
    expect(qrImage.height, closeTo(40 * scale, .01));
    expect(settingsImage.width, closeTo(40 * scale, .01));
    expect(settingsImage.height, closeTo(40 * scale, .01));
    expect(qrTap.width / qrImage.width, closeTo(2, .01));
    expect(settingsTap.width / settingsImage.width, closeTo(2, .01));
    expect(
      settingsImage.center.dx - qrImage.center.dx,
      closeTo(qrImage.width * 2, .01),
    );
    expect(toolbar.width, closeTo(190 * scale, .01));

    await tester.tap(find.byKey(const ValueKey('my-profile-qr')));
    await tester.tap(find.byKey(const ValueKey('my-profile-settings')));
    expect(qrOpened, isTrue);
    expect(settingsOpened, isTrue);
  });
}
