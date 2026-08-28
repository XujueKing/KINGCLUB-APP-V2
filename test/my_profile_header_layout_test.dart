import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';

void main() {
  testWidgets('我的主页头图信息关系遵循旧版 750rpx 标尺', (tester) async {
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
    final cover = tester.getRect(
      find.byKey(const ValueKey('my-profile-cover')),
    );
    final avatar = tester.getRect(
      find.byKey(const ValueKey('my-profile-empty-avatar')),
    );

    expect(cover.height, closeTo(540 * scale, .01));
    expect(cover.bottom, closeTo(540 * scale, .01));
    expect(avatar.top, closeTo(400 * scale, .01));
    expect(avatar.width, closeTo(180 * scale, .01));
    expect(avatar.bottom - cover.bottom, closeTo(40 * scale, .01));

    final nickname = tester.getRect(find.text('杨嘉琪'));
    final account = tester.getRect(find.text('账号：K45600000199'));
    expect(nickname.left, closeTo(avatar.right + 30 * scale, .01));
    expect(account.left, closeTo(nickname.left, .01));

    final likes = tester.getRect(
      find.byKey(const ValueKey('my-profile-stat-获赞')),
    );
    final follows = tester.getRect(
      find.byKey(const ValueKey('my-profile-stat-关注')),
    );
    expect(likes.width, closeTo(104 * scale, .01));
    expect(follows.center.dx - likes.center.dx, closeTo(104 * scale, .01));
  });
}
