import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';

void main() {
  testWidgets('我的主页字体遵循旧版 750rpx 标尺', (tester) async {
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

    TextStyle styleOf(String text) =>
        tester.widget<Text>(find.text(text)).style!;

    expect(styleOf('杨嘉琪').fontSize, 20);
    expect(styleOf('杨嘉琪').fontWeight, FontWeight.w600);
    expect(styleOf('账号：K45600000199').fontSize, 11.5);
    expect(styleOf('获赞').fontSize, 13.5);
    expect(styleOf('获赞').fontWeight, FontWeight.w400);
    expect(styleOf('余额：¥ 0.00').fontSize, 14);
    expect(styleOf('♂ 24岁').fontSize, 12.5);
    expect(styleOf('动态').fontSize, 17);
    expect(styleOf('动态').fontWeight, FontWeight.w600);
    expect(styleOf('作品').fontSize, 14.5);
    expect(styleOf('作品').fontWeight, FontWeight.w400);
  });
}
