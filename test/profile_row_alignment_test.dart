import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/edit_profile_page.dart';
import 'package:kingclub/src/features/profile_settings/presentation/settings_page.dart';

void main() {
  Widget frame(Widget child, {TextScaler textScaler = TextScaler.noScaling}) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(393, 852),
          textScaler: textScaler,
        ),
        child: child,
      ),
    );
  }

  void expectSameArrowColumn(WidgetTester tester, List<String> keys) {
    final positions = keys
        .map((key) => tester.getCenter(find.byKey(ValueKey(key))).dx)
        .toList();
    for (final position in positions.skip(1)) {
      expect(position, closeTo(positions.first, 0.01));
    }
  }

  testWidgets('编辑资料所有右箭头使用同一固定列', (tester) async {
    await tester.pumpWidget(
      frame(const EditProfilePage(nickname: '杨嘉琪', signature: '')),
    );

    expectSameArrowColumn(tester, const [
      'edit-profile-arrow-nickname',
      'edit-profile-arrow-signature',
      'edit-profile-arrow-city',
      'edit-profile-arrow-occupation',
      'edit-profile-arrow-height',
    ]);
  });

  testWidgets('设置页含有和不含辅助文字的箭头依然对齐', (tester) async {
    await tester.pumpWidget(frame(const SettingsPage()));

    expectSameArrowColumn(tester, const [
      'settings-arrow-payment',
      'settings-arrow-notification',
      'settings-arrow-cache',
      'settings-arrow-about',
      'settings-arrow-deletion',
    ]);
  });

  testWidgets('200% 字体下编辑资料箭头列不偏移', (tester) async {
    await tester.pumpWidget(
      frame(
        const EditProfilePage(nickname: '杨嘉琪', signature: ''),
        textScaler: const TextScaler.linear(2),
      ),
    );

    expectSameArrowColumn(tester, const [
      'edit-profile-arrow-nickname',
      'edit-profile-arrow-signature',
      'edit-profile-arrow-city',
    ]);
    expect(tester.takeException(), isNull);
  });
}
