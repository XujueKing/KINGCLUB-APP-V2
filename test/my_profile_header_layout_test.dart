import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';

void main() {
  testWidgets('资产型我的主页遵循旧版 750rpx 主栏与垂直层级', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(393, 852)),
          child: Scaffold(body: MyProfilePage()),
        ),
      ),
    );
    await tester.pump();

    const scale = 393 / 750;
    final wallet = tester.getRect(
      find.byKey(const ValueKey('my-profile-wallet-account')),
    );
    final voucher = tester.getRect(
      find.byKey(const ValueKey('my-profile-voucher-account')),
    );
    final firstMenu = tester.getRect(
      find.byKey(const ValueKey('my-profile-menu-qr')),
    );
    final lastMenu = tester.getRect(
      find.byKey(const ValueKey('my-profile-menu-about')),
    );
    expect(wallet.left, closeTo((393 - 660 * scale) / 2, .01));
    expect(voucher.right, closeTo((393 + 660 * scale) / 2, .01));
    expect(wallet.width, closeTo((660 * scale - 1) / 2, .01));
    expect(voucher.width, closeTo((660 * scale - 1) / 2, .01));
    expect(firstMenu.width, closeTo(660 * scale, .01));
    expect(firstMenu.top, greaterThan(wallet.bottom));
    expect(lastMenu.top, greaterThan(firstMenu.top));
  });
}
