import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/presentation/aa_mock_models.dart';
import 'package:kingclub/src/features/club/presentation/aa_order_confirmation_page.dart';
import 'package:kingclub/src/features/club/presentation/aa_package_detail_page.dart';
import 'package:kingclub/src/features/club/presentation/aa_reservations_page.dart';

void main() {
  testWidgets('legacy AA reservation completes the local Fake flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AaReservationsPage(onBack: () {}),
      ),
    );

    expect(find.text('一起玩AA预定'), findsOneWidget);
    expect(find.text('微醺畅饮套餐'), findsOneWidget);

    await tester.tap(find.text('加入').first);
    await tester.pumpAndSettle();
    expect(find.text('POSITIONING CARD'), findsOneWidget);
    expect(find.text('抢订'), findsOneWidget);

    await tester.tap(find.text('抢订'));
    await tester.pumpAndSettle();
    expect(find.text('确认订单'), findsOneWidget);
    expect(find.text('立即付款'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('aa-requote-loading-banner')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('已选20元AA券'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    final termsCheckbox = find.byKey(const ValueKey('aa-terms-checkbox'));
    await tester.scrollUntilVisible(
      termsCheckbox,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    tester.widget<Checkbox>(termsCheckbox).onChanged!(true);
    await tester.pump();
    final payButton = find.byKey(const ValueKey('aa-pay-button'));
    expect(tester.widget<FilledButton>(payButton).onPressed, isNotNull);
    tester.widget<FilledButton>(payButton).onPressed!();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('已生成 Fake 待支付订单'), findsOneWidget);
    expect(find.textContaining('真实支付模块尚未接入'), findsOneWidget);
  });

  testWidgets(
    'AA landing exposes existing reservation and offline Fake states',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KingTheme.dark,
          home: AaReservationsPage(onBack: () {}),
        ),
      );

      await tester.longPress(find.byKey(const ValueKey('legacy-club-title')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('aa-scenario-pendingPayment')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('aa-pending-card')), findsOneWidget);
      expect(find.text('已有预订'), findsNWidgets(aaMockPackageCount));

      await tester.longPress(find.byKey(const ValueKey('legacy-club-title')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('aa-scenario-offline')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('aa-offline-banner')), findsOneWidget);
      expect(find.text('离线'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('aa-offline-refresh')));
      await tester.pump();
      expect(find.byKey(const ValueKey('aa-available-card')), findsOneWidget);

      await tester.longPress(find.byKey(const ValueKey('legacy-club-title')));
      await tester.pumpAndSettle();
      final noRecommendation = find.byKey(
        const ValueKey('aa-scenario-noRecommendation'),
      );
      await tester.drag(find.byType(ListView).last, const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(noRecommendation);
      await tester.pumpAndSettle();
      expect(find.text('暂无推荐'), findsOneWidget);
      expect(find.text('加入'), findsNWidgets(2));
    },
  );

  testWidgets('AA package requires acknowledging a changed price', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AaPackageDetailPage(
          package: aaMockPackages.first,
          serviceDate: '08.26',
        ),
      ),
    );

    await tester.longPress(find.byKey(const ValueKey('aa-package-title')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('aa-package-scenario-priceUpdated')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('aa-package-price-updated')),
      findsOneWidget,
    );
    expect(find.text('确认新价格'), findsOneWidget);
    expect(find.textContaining('¥218.00'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('aa-package-bottom-action')));
    await tester.pump();
    expect(find.text('抢订'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('aa-package-bottom-action')));
    await tester.pumpAndSettle();
    expect(find.text('确认订单'), findsOneWidget);
    expect(find.text('¥218.00'), findsWidgets);
  });

  testWidgets('sold out AA package only returns to the list', (tester) async {
    var returned = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => AaPackageDetailPage(
                    package: aaMockPackages.first,
                    serviceDate: '08.26',
                  ),
                ),
              );
              returned = true;
            },
            child: const Text('打开套餐'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开套餐'));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('aa-package-title')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('aa-package-scenario-soldOut')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('aa-package-sold-out')), findsOneWidget);
    expect(find.text('返回列表'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('aa-package-bottom-action')));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(find.text('打开套餐'), findsOneWidget);
  });

  testWidgets('expired AA quote blocks payment until refreshed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AaOrderConfirmationPage(
          package: aaMockPackages.first,
          serviceDate: '08.26',
        ),
      ),
    );

    await tester.longPress(find.byKey(const ValueKey('aa-confirmation-title')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('aa-confirmation-scenario-quoteExpired')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('aa-quote-expired-banner')),
      findsOneWidget,
    );
    final payButton = find.byKey(const ValueKey('aa-pay-button'));
    expect(tester.widget<FilledButton>(payButton).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('aa-refresh-quote')));
    await tester.pump();
    expect(find.byKey(const ValueKey('aa-quote-expired-banner')), findsNothing);
  });

  testWidgets('AA submission sold out does not create or charge an order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AaReservationsPage(onBack: () {}),
      ),
    );
    await tester.tap(find.text('加入').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('aa-package-bottom-action')));
    await tester.pumpAndSettle();
    await _selectConfirmationScenario(tester, 'soldOutOnSubmit');
    await _agreeAndSubmit(tester);

    expect(
      find.byKey(const ValueKey('aa-submission-outcome-soldOut')),
      findsOneWidget,
    );
    expect(find.textContaining('本次未创建订单，也不会扣款'), findsOneWidget);
    expect(_payButton(tester).onPressed, isNull);
    expect(find.text('已售罄'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('aa-submission-outcome-action')),
    );
    await tester.pumpAndSettle();
    expect(find.text('一起玩AA预定'), findsOneWidget);
    expect(find.text('确认订单'), findsNothing);
  });

  testWidgets('AA duplicate reservation keeps the existing Fake order', (
    tester,
  ) async {
    await _pumpConfirmation(tester);
    await _selectConfirmationScenario(tester, 'duplicateReservation');
    await _agreeAndSubmit(tester);

    expect(
      find.byKey(const ValueKey('aa-submission-outcome-duplicateReservation')),
      findsOneWidget,
    );
    expect(find.textContaining('KC-AA-0826-01'), findsOneWidget);
    expect(find.textContaining('不会再创建第二张订单'), findsOneWidget);
    expect(_payButton(tester).onPressed, isNull);
    expect(find.text('已有预订'), findsOneWidget);
  });

  testWidgets('AA unknown result reconciles the same Fake submission', (
    tester,
  ) async {
    await _pumpConfirmation(tester);
    await _selectConfirmationScenario(tester, 'resultUnknown');
    await _agreeAndSubmit(tester);

    expect(
      find.byKey(const ValueKey('aa-submission-outcome-resultUnknown')),
      findsOneWidget,
    );
    expect(find.textContaining('请勿重复提交或支付'), findsOneWidget);
    expect(_payButton(tester).onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('aa-submission-outcome-action')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('已生成 Fake 待支付订单'), findsOneWidget);
    expect(find.textContaining('席位模拟保留 10 分钟'), findsOneWidget);
  });

  testWidgets('AA ineligible result exits the write flow without charging', (
    tester,
  ) async {
    await _pumpConfirmation(tester);
    await _selectConfirmationScenario(tester, 'ineligibleOnSubmit');
    await _agreeAndSubmit(tester);

    expect(
      find.byKey(const ValueKey('aa-submission-outcome-ineligible')),
      findsOneWidget,
    );
    expect(find.textContaining('本次未创建订单，也不会扣款'), findsOneWidget);
    expect(find.text('资格失效'), findsOneWidget);
    expect(_payButton(tester).onPressed, isNull);
  });

  testWidgets('AA offline quote is read only until Fake network recovers', (
    tester,
  ) async {
    await _pumpConfirmation(tester);
    await _selectConfirmationScenario(tester, 'offline');

    expect(
      find.byKey(const ValueKey('aa-submission-outcome-offline')),
      findsOneWidget,
    );
    expect(find.textContaining('正在显示缓存报价，仅供查看'), findsOneWidget);
    expect(find.text('当前离线'), findsOneWidget);
    expect(_payButton(tester).onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('aa-submission-outcome-action')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('aa-submission-outcome-offline')),
      findsNothing,
    );
    expect(find.text('立即付款'), findsOneWidget);
  });

  testWidgets('AA session invalid clears quote and requests login reset', (
    tester,
  ) async {
    var resetRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: AaOrderConfirmationPage(
          package: aaMockPackages.first,
          serviceDate: '08.26',
          onSessionResetRequested: () => resetRequested = true,
        ),
      ),
    );
    await _selectConfirmationScenario(tester, 'sessionInvalid');

    expect(find.text('登录状态已失效'), findsOneWidget);
    expect(find.text('微醺畅饮套餐'), findsNothing);
    expect(find.byKey(const ValueKey('aa-pay-button')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('aa-session-reset-action')));
    await tester.pump();
    expect(resetRequested, isTrue);
  });

  testWidgets('AA initial loading hides amounts until Fake quote is ready', (
    tester,
  ) async {
    await _pumpConfirmation(tester);
    await _selectConfirmationScenario(tester, 'initialLoading');

    expect(find.text('正在获取最新报价'), findsOneWidget);
    expect(find.text('实付￥--'), findsOneWidget);
    expect(find.text('微醺畅饮套餐'), findsNothing);
    expect(_payButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('aa-initial-load-action')));
    await tester.pump();
    expect(find.text('微醺畅饮套餐'), findsOneWidget);
    expect(find.text('立即付款'), findsOneWidget);
  });

  testWidgets('AA requote retains old amount then publishes changed quote', (
    tester,
  ) async {
    await _pumpConfirmation(tester);
    final firstDeduction = find.byType(Checkbox).first;

    tester.widget<Checkbox>(firstDeduction).onChanged!(true);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('aa-requote-loading-banner')),
      findsOneWidget,
    );
    expect(find.textContaining('已选20元AA券'), findsNothing);
    expect(_payButton(tester).onPressed, isNull);

    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey('aa-quote-changed-banner')),
      findsOneWidget,
    );
    expect(find.textContaining('已选20元AA券'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    expect(_payButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('aa-dismiss-quote-changed')));
    await tester.pump();
    expect(find.byKey(const ValueKey('aa-quote-changed-banner')), findsNothing);
  });

  testWidgets('invalid AA quote clears business content and returns', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => AaOrderConfirmationPage(
                  package: aaMockPackages.first,
                  serviceDate: '08.26',
                ),
              ),
            ),
            child: const Text('打开确认页'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开确认页'));
    await tester.pumpAndSettle();
    await _selectConfirmationScenario(tester, 'invalidRef');

    expect(find.text('报价已失效'), findsOneWidget);
    expect(find.text('微醺畅饮套餐'), findsNothing);
    expect(find.byKey(const ValueKey('aa-pay-button')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('aa-invalid-ref-action')));
    await tester.pumpAndSettle();
    expect(find.text('打开确认页'), findsOneWidget);
  });

  testWidgets('zero cash AA quote confirms without opening payment', (
    tester,
  ) async {
    await _pumpConfirmation(tester);
    await _selectConfirmationScenario(tester, 'zeroCash');

    expect(find.text('确认预订'), findsOneWidget);
    expect(find.text('无需调用支付'), findsOneWidget);
    expect(find.textContaining('0.00 元'), findsOneWidget);

    await _agreeAndSubmit(tester);
    expect(find.text('Fake 预订已确认'), findsOneWidget);
    expect(find.textContaining('实付 ¥0.00'), findsOneWidget);
    expect(find.textContaining('没有拉起支付'), findsOneWidget);
    expect(find.text('已生成 Fake 待支付订单'), findsNothing);
  });
}

const aaMockPackageCount = 3;

Future<void> _pumpConfirmation(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: KingTheme.dark,
      home: AaOrderConfirmationPage(
        package: aaMockPackages.first,
        serviceDate: '08.26',
      ),
    ),
  );
}

Future<void> _selectConfirmationScenario(
  WidgetTester tester,
  String scenario,
) async {
  await tester.longPress(find.byKey(const ValueKey('aa-confirmation-title')));
  await tester.pumpAndSettle();
  final target = find.byKey(ValueKey('aa-confirmation-scenario-$scenario'));
  await tester.scrollUntilVisible(
    target,
    160,
    scrollable: find.byType(Scrollable).last,
  );
  tester.widget<ListTile>(target).onTap!();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _agreeAndSubmit(WidgetTester tester) async {
  final terms = find.byKey(const ValueKey('aa-terms-checkbox'));
  await tester.scrollUntilVisible(
    terms,
    180,
    scrollable: find.byType(Scrollable).last,
  );
  tester.widget<Checkbox>(terms).onChanged!(true);
  await tester.pump();
  _payButton(tester).onPressed!();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

FilledButton _payButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const ValueKey('aa-pay-button')));
