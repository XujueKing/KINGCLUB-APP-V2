import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/presentation/vip_party_management_page.dart';

void main() {
  testWidgets('management preserves legacy overview bill and member tabs', (
    tester,
  ) async {
    await _pumpManagement(tester);

    expect(find.text('V8 卡座'), findsOneWidget);
    expect(find.text('概况'), findsOneWidget);
    expect(find.text('星光香槟套餐'), findsOneWidget);
    expect(find.text('服务员'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('vip-manage-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vip-manage-bill')), findsOneWidget);
    expect(find.text('星光香槟套餐 × 1'), findsOneWidget);
    expect(find.textContaining('商品确认'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vip-manage-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('青铜'), findsOneWidget);
    expect(find.text('释放占位'), findsOneWidget);
    expect(find.text('撤销邀请'), findsOneWidget);
    expect(find.text('踢人'), findsNothing);
  });

  testWidgets('host can release only an unpaid hold', (tester) async {
    await _pumpManagement(tester);
    await tester.tap(find.byKey(const ValueKey('vip-manage-tab-2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('vip-release-hold')));
    await tester.pumpAndSettle();
    expect(find.text('释放未付款占位？'), findsOneWidget);
    expect(find.textContaining('已付款成员不会受到影响'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '释放占位').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vip-unpaid-member')), findsNothing);
    expect(find.text('小鹿'), findsOneWidget);
  });

  testWidgets('single friend invite requires selection and confirmation', (
    tester,
  ) async {
    await _pumpManagement(tester);
    await tester.tap(find.byKey(const ValueKey('vip-manage-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-invite-friend')));
    await tester.pumpAndSettle();
    expect(find.text('选择一位 KingClub 好友'), findsOneWidget);

    await tester.tap(find.text('林晚'));
    await tester.pumpAndSettle();
    expect(find.text('邀请 林晚？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '发送邀请'));
    await tester.pumpAndSettle();
    expect(find.text('林晚'), findsOneWidget);
    expect(find.textContaining('刚刚邀请'), findsOneWidget);
  });

  testWidgets('offline and locked management states disable writes', (
    tester,
  ) async {
    await _pumpManagement(tester);
    await _selectScenario(tester, 'offline');
    expect(find.textContaining('当前离线'), findsOneWidget);
    final recruitmentSwitch = tester.widget<Switch>(
      find.byKey(const ValueKey('vip-recruitment-switch')),
    );
    expect(recruitmentSwitch.onChanged, isNull);

    await _selectScenario(tester, 'permissionLost');
    expect(find.text('局长管理权限已失效'), findsOneWidget);
    expect(find.text('青铜'), findsNothing);
  });
}

Future<void> _pumpManagement(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: KingTheme.dark,
      home: VipPartyManagementPage(onBack: () {}),
    ),
  );
}

Future<void> _selectScenario(WidgetTester tester, String scenario) async {
  await tester.longPress(find.byKey(const ValueKey('legacy-club-title')));
  await tester.pumpAndSettle();
  tester
      .widget<ListTile>(find.byKey(ValueKey('vip-manage-scenario-$scenario')))
      .onTap!();
  await tester.pumpAndSettle();
}
