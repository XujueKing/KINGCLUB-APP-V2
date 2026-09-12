import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';

void main() {
  testWidgets('资产型我的主页字体遵循旧版 750rpx 标尺', (tester) async {
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
    TextStyle styleForKey(String key) => tester
        .widget<Text>(
          find
              .descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(Text),
              )
              .first,
        )
        .style!;

    final title = tester
        .widget<Text>(find.byKey(const ValueKey('my-profile-total-title')))
        .style!;
    expect(title.fontSize, closeTo(30 * scale, .01));
    expect(
      styleForKey('my-profile-total-balance').fontSize,
      closeTo(66 * scale, .01),
    );
    expect(styleForKey('my-profile-total-balance').fontWeight, FontWeight.w600);
    expect(
      styleForKey('my-profile-wallet-account').fontSize,
      closeTo(36 * scale, .01),
    );
    expect(
      styleForKey('my-profile-menu-qr').fontSize,
      closeTo(31 * scale, .01),
    );
    expect(styleForKey('my-profile-menu-qr').fontWeight, FontWeight.w400);
  });
}
