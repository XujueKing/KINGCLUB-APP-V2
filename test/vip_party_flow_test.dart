import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/presentation/vip_party_page.dart';

void main() {
  testWidgets('VIP browse keeps the legacy card and inline member layout', (
    tester,
  ) async {
    await _pumpVip(tester);

    expect(find.text('VIP组局'), findsOneWidget);
    expect(find.text('UI MOCK'), findsNothing);
    expect(find.textContaining('预选卡座和套餐'), findsOneWidget);
    expect(find.text('V8'), findsOneWidget);
    expect(find.text('星光香槟套餐'), findsOneWidget);

    await tester.tap(find.text('V8'));
    await tester.pumpAndSettle();
    expect(find.text('青铜（局长）'), findsOneWidget);
    expect(find.text('局长'), findsOneWidget);
    expect(find.text('邀请'), findsWidgets);
  });

  testWidgets('VIP viewer join creates only a Fake pending payment intent', (
    tester,
  ) async {
    await _pumpVip(tester);
    await tester.scrollUntilVisible(
      find.text('V6'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('V6'));
    await tester.pumpAndSettle();
    final join = find.widgetWithText(FilledButton, '申请加入');
    await tester.scrollUntilVisible(
      join,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    tester.widget<FilledButton>(join).onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('确认申请加入'), findsOneWidget);
    expect(find.textContaining('成员各付 ¥488.00'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('vip-confirm-join')));
    await tester.pumpAndSettle();
    expect(find.text('已生成 Fake 待支付意图'), findsOneWidget);
    expect(find.textContaining('真实支付模块尚未接入'), findsOneWidget);
  });

  testWidgets('VIP empty and offline states preserve safe page context', (
    tester,
  ) async {
    await _pumpVip(tester);
    await _selectScenario(tester, 'empty');
    expect(find.byKey(const ValueKey('vip-empty-state')), findsOneWidget);
    expect(find.text('V8'), findsNothing);
    expect(find.textContaining('预选卡座和套餐'), findsOneWidget);

    await _selectScenario(tester, 'offline');
    expect(find.byKey(const ValueKey('vip-offline-banner')), findsOneWidget);
    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '预定一个新卡座'),
    );
    expect(createButton.onPressed, isNull);
  });

  testWidgets('host-sponsored VIP party confirms a zero cash Fake seat', (
    tester,
  ) async {
    await _pumpVip(tester);
    await _selectScenario(tester, 'hostSponsored');
    await tester.scrollUntilVisible(
      find.text('V6'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('V6'));
    await tester.pumpAndSettle();
    final join = find.widgetWithText(FilledButton, '申请加入');
    await tester.scrollUntilVisible(
      join,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    tester.widget<FilledButton>(join).onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('确认免费加入'), findsOneWidget);
    expect(find.textContaining('本人应付 ¥0.00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vip-confirm-join')));
    await tester.pumpAndSettle();
    expect(find.text('Fake 加入成功'), findsOneWidget);
    expect(find.textContaining('没有拉起支付'), findsOneWidget);
  });
}

Future<void> _pumpVip(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: KingTheme.dark,
      home: VipPartyPage(
        onBack: () {},
        onCreateParty: (_) {},
        onManageParty: () {},
        onOpenTicket: () {},
      ),
    ),
  );
}

Future<void> _selectScenario(WidgetTester tester, String scenario) async {
  await tester.longPress(find.byKey(const ValueKey('legacy-club-title')));
  await tester.pumpAndSettle();
  final target = find.byKey(ValueKey('vip-scenario-$scenario'));
  tester.widget<ListTile>(target).onTap!();
  await tester.pumpAndSettle();
}
