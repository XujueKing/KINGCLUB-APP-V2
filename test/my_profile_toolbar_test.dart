import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';

void main() {
  testWidgets('资产型我的主页保留单一设置入口和完整菜单入口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var qrOpened = false;
    var settingsOpened = false;
    var aboutOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(393, 852)),
          child: Scaffold(
            body: MyProfilePage(
              onOpenPersonalQr: () => qrOpened = true,
              onOpenSettings: () => settingsOpened = true,
              onOpenAbout: () => aboutOpened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final settings = find.byKey(const ValueKey('my-profile-settings'));
    expect(tester.getSize(settings), const Size(48, 48));
    expect(find.text('我的二维码'), findsOneWidget);
    expect(find.text('我的个人信息'), findsOneWidget);
    expect(find.text('账单记录'), findsOneWidget);
    expect(find.text('关于KINGBAR'), findsOneWidget);

    await tester.tap(settings);
    await tester.tap(find.byKey(const ValueKey('my-profile-menu-qr')));
    await tester.tap(find.byKey(const ValueKey('my-profile-menu-about')));
    expect(settingsOpened, isTrue);
    expect(qrOpened, isTrue);
    expect(aboutOpened, isTrue);
  });
}
