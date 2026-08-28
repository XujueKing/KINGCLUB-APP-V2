import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/presentation/order_center_page.dart';
import 'package:kingclub/src/features/membership_wallet/presentation/asset_ledger_page.dart';

void main() {
  Widget subject({
    AssetLedgerType type = AssetLedgerType.cashBalance,
    AssetLedgerScenario scenario = AssetLedgerScenario.allEnabled,
    ValueChanged<FakeOrderRef>? onOpenOrder,
    VoidCallback? onSessionResetRequested,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: AssetLedgerPage(
        key: ValueKey('${type.name}-${scenario.name}'),
        initialType: type,
        initialScenario: scenario,
        onBack: () {},
        onOpenOrder: onOpenOrder,
        onSessionResetRequested: onSessionResetRequested,
      ),
    );
  }

  testWidgets('复刻旧版标题四分类 tab 年度摘要和流水层级', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('账单记录'), findsOneWidget);
    expect(find.text('订单'), findsOneWidget);
    expect(find.text('余额'), findsWidgets);
    expect(find.text('金币'), findsWidgets);
    expect(find.text('钻石'), findsWidgets);
    expect(find.byKey(const ValueKey('asset-tab-order')), findsOneWidget);
    expect(find.text('2026年度'), findsOneWidget);
    expect(find.text('星光香槟套餐'), findsOneWidget);
    expect(find.text('-¥68.00'), findsOneWidget);
    expect(find.text('加载更多'), findsNothing);
    expect(find.text('充值'), findsNothing);
    expect(find.text('提现'), findsNothing);
    expect(find.text('转赠'), findsNothing);
  });

  testWidgets('顶部返回键可见并执行返回动作', (tester) async {
    var backed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AssetLedgerPage(onBack: () => backed = true),
      ),
    );

    final back = find.byKey(const ValueKey('asset-ledger-back'));
    expect(back, findsOneWidget);
    expect(tester.getTopLeft(back).dx, lessThan(40));
    await tester.tap(back);
    expect(backed, isTrue);
  });

  testWidgets('订单与三种资产保持旧版四页签且单位可切换', (tester) async {
    await tester.pumpWidget(subject());

    await tester.tap(find.byKey(const ValueKey('asset-tab-order')));
    await tester.pump();
    expect(find.text('星光香槟套餐'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('asset-tab-goldCoin')));
    await tester.pump();
    expect(find.text('会员活动奖励'), findsOneWidget);
    expect(find.text('+50 枚'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('asset-tab-diamond')));
    await tester.pump();
    expect(find.text('会员等级奖励'), findsOneWidget);
    expect(find.text('+8 枚'), findsOneWidget);
  });

  testWidgets('未启用钻石时不显示假零占位', (tester) async {
    await tester.pumpWidget(
      subject(scenario: AssetLedgerScenario.balanceAndCoinOnly),
    );

    expect(find.byKey(const ValueKey('asset-tab-diamond')), findsNothing);
  });

  testWidgets('零资产是权威零且当前流水为空', (tester) async {
    await tester.pumpWidget(subject(scenario: AssetLedgerScenario.zeroAssets));

    expect(find.text('当前资产和年度暂无流水'), findsOneWidget);
  });

  testWidgets('摘要失败不通过流水推算并可恢复', (tester) async {
    await tester.pumpWidget(
      subject(scenario: AssetLedgerScenario.summaryFailure),
    );

    expect(find.text('资产摘要加载失败'), findsOneWidget);
    expect(find.textContaining('未使用本地流水推算余额'), findsOneWidget);
    expect(find.text('星光香槟套餐'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('asset-summary-retry')));
    await tester.pump();
    expect(find.text('星光香槟套餐'), findsOneWidget);
  });

  testWidgets('pending 与 reversed 均明确显示状态', (tester) async {
    await tester.pumpWidget(
      subject(scenario: AssetLedgerScenario.pendingEntry),
    );
    expect(find.text('退款处理中'), findsOneWidget);
    expect(find.textContaining('处理中'), findsWidgets);

    await tester.pumpWidget(
      subject(scenario: AssetLedgerScenario.reversedEntry),
    );
    expect(find.text('活动金币奖励'), findsOneWidget);
    expect(find.textContaining('已冲正'), findsOneWidget);
    expect(find.text('活动奖励冲正'), findsOneWidget);
  });

  testWidgets('普通流水只在当前页展开 Fake 摘要', (tester) async {
    await tester.pumpWidget(
      subject(scenario: AssetLedgerScenario.ordinaryExpanded),
    );

    await tester.tap(
      find.byKey(const ValueKey('asset-entry-ledger-balance-refund')),
    );
    await tester.pump();
    expect(find.text('退款已由 Fake 服务端确认入账。'), findsOneWidget);
  });

  testWidgets('关联订单仅发出不透明 FakeOrderRef', (tester) async {
    FakeOrderRef? opened;
    await tester.pumpWidget(subject(onOpenOrder: (value) => opened = value));

    await tester.tap(
      find.byKey(const ValueKey('asset-entry-ledger-order-spend')),
    );
    expect(opened?.opaqueId, 'order-scan-v8-0827');
  });

  testWidgets('加载更多失败保留列表并可安全重试', (tester) async {
    await tester.pumpWidget(
      subject(scenario: AssetLedgerScenario.nextPageFailure),
    );

    expect(find.text('星光香槟套餐'), findsOneWidget);
    expect(find.byKey(const ValueKey('asset-load-more-retry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('asset-load-more-retry')));
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.text('余额历史调整'), findsOneWidget);
    expect(find.text('已加载全部流水'), findsOneWidget);
  });

  testWidgets('年度切换重置并加载对应空状态', (tester) async {
    await tester.pumpWidget(subject());

    await tester.tap(find.byKey(const ValueKey('asset-year-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2024年度').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('当前资产和年度暂无流水'), findsOneWidget);
  });

  testWidgets('离线缓存保持只读并标记 asOf', (tester) async {
    await tester.pumpWidget(
      subject(scenario: AssetLedgerScenario.offlineCached),
    );

    expect(find.textContaining('离线只读'), findsOneWidget);
    expect(find.textContaining('缓存更新于'), findsOneWidget);
    expect(find.text('充值'), findsNothing);
  });

  testWidgets('会话失效先清空资产再请求登录重置', (tester) async {
    var reset = false;
    await tester.pumpWidget(
      subject(
        scenario: AssetLedgerScenario.sessionInvalid,
        onSessionResetRequested: () => reset = true,
      ),
    );

    expect(find.text('登录状态已失效'), findsOneWidget);
    expect(find.text('¥120.00'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('asset-session-reset')));
    expect(reset, isTrue);
  });
}
