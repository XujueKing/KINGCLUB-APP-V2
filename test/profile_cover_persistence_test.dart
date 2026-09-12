import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/profile_settings/presentation/edit_profile_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';

Widget _subject({
  VoidCallback? onOpenPersonalInfo,
  Future<EditableProfileResult?> Function(String, String, String)?
  onOpenLegacyEditor,
}) {
  return MaterialApp(
    theme: KingTheme.dark,
    home: MediaQuery(
      data: const MediaQueryData(size: Size(393, 852)),
      child: Scaffold(
        body: MyProfilePage(
          onOpenPersonalInfo: onOpenPersonalInfo,
          onOpenEditProfile: onOpenLegacyEditor,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('我的个人信息触发小程序资料页入口而非旧编辑页', (tester) async {
    var personalInfoOpened = 0;
    var legacyEditorOpened = 0;
    await tester.pumpWidget(
      _subject(
        onOpenPersonalInfo: () => personalInfoOpened++,
        onOpenLegacyEditor: (_, _, _) async {
          legacyEditorOpened++;
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(const ValueKey('my-profile-menu-info'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);

    expect(personalInfoOpened, 1);
    expect(legacyEditorOpened, 0);
  });

  testWidgets('无路由回调时仍打开九行个人信息页', (tester) async {
    await tester.pumpWidget(_subject());
    await tester.pumpAndSettle();

    final entry = find.byKey(const ValueKey('my-profile-menu-info'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('我的个人信息'), findsOneWidget);
    expect(find.text('年龄/性别'), findsOneWidget);
    expect(find.text('修改支付密码'), findsOneWidget);
  });
}
