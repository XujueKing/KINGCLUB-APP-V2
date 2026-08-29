import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/presentation/vip_party_create_page.dart';

void main() {
  testWidgets('create page keeps legacy ordering and requires rules', (
    tester,
  ) async {
    await _pumpCreate(tester);

    expect(find.text('预定一个卡颜局'), findsOneWidget);
    expect(find.text('选择一个卡座：'), findsOneWidget);
    expect(find.text('聚会人数（最大10人）：'), findsOneWidget);
    expect(find.text('星光香槟套餐'), findsOneWidget);
    expect(find.text('AI卡颜'), findsNothing);
    expect(find.text('年龄限制'), findsNothing);

    var submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('vip-create-submit')),
    );
    expect(submit.onPressed, isNull);
    await _acceptTerms(tester);
    await tester.pump();
    submit = tester.widget<FilledButton>(
      find.byKey(const ValueKey('vip-create-submit')),
    );
    expect(submit.onPressed, isNotNull);
  });

  testWidgets('changing a package requotes and clears terms agreement', (
    tester,
  ) async {
    await _pumpCreate(tester);
    await _acceptTerms(tester);
    await tester.drag(
      find.byKey(const ValueKey('vip-create-form')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-create-package')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vip-create-option-1')));
    await tester.pumpAndSettle();
    expect(find.text('微醺派对套餐'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('vip-create-submit')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('paid create produces Fake pending payment only', (tester) async {
    await _pumpCreate(tester);
    await _acceptTerms(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vip-create-submit')));
    await tester.pumpAndSettle();

    expect(find.text('待支付订单已生成'), findsOneWidget);
    expect(find.textContaining('席位将保留 10 分钟'), findsOneWidget);
    expect(find.textContaining('Fake'), findsNothing);
    expect(find.textContaining('Mock'), findsNothing);
    expect(find.textContaining('支付成功前不会标记为已付款'), findsOneWidget);
  });

  testWidgets('quote expiry refreshes without submitting', (tester) async {
    await _pumpCreate(tester);
    await _selectScenario(tester, 'quoteExpired');
    expect(find.text('当前报价已过期，请先刷新报价。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('vip-create-submit')));
    await tester.pumpAndSettle();
    expect(find.text('当前报价已过期，请先刷新报价。'), findsNothing);
    expect(find.text('确认创建'), findsOneWidget);
  });

  testWidgets('result unknown keeps idempotent reconciliation language', (
    tester,
  ) async {
    await _pumpCreate(tester);
    await _selectScenario(tester, 'resultUnknown');
    await _acceptTerms(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('vip-create-submit')));
    await tester.pumpAndSettle();
    expect(find.text('创建结果确认中'), findsOneWidget);
    expect(find.textContaining('不会重复创建'), findsOneWidget);
  });

  testWidgets('zero cash quote confirms without opening payment', (
    tester,
  ) async {
    await _pumpCreate(tester);
    await _selectScenario(tester, 'zeroCash');
    await _acceptTerms(tester);
    await tester.tap(find.byKey(const ValueKey('vip-create-submit')));
    await tester.pumpAndSettle();
    expect(find.text('组局创建成功'), findsOneWidget);
    expect(find.textContaining('Fake'), findsNothing);
    expect(find.textContaining('当前实付 ¥0.00'), findsOneWidget);
    expect(find.textContaining('无需支付'), findsOneWidget);
  });
}

Future<void> _pumpCreate(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: KingTheme.dark,
      home: VipPartyCreatePage(onBack: () {}),
    ),
  );
}

Future<void> _selectScenario(WidgetTester tester, String scenario) async {
  await tester.longPress(find.byKey(const ValueKey('legacy-club-title')));
  await tester.pumpAndSettle();
  final target = find.byKey(ValueKey('vip-create-scenario-$scenario'));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find.byType(Scrollable).last,
    );
  }
  tester.widget<ListTile>(target).onTap!();
  await tester.pumpAndSettle();
}

Future<void> _acceptTerms(WidgetTester tester) async {
  final terms = find.byKey(const ValueKey('vip-create-terms'));
  await tester.scrollUntilVisible(
    terms,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  tester.widget<Checkbox>(terms).onChanged!(true);
  await tester.pump();
}
