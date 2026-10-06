import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kingclub/src/features/partners/presentation/partner_policy_page.dart';
import 'package:kingclub/src/features/partners/presentation/partner_tasks_page.dart';

Widget app(Widget page) => MaterialApp(
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData.dark(),
  home: page,
);
void main() {
  testWidgets('no default fee or write when store has no policy', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      app(
        PartnerPolicyPage(
          storeRef: 'store',
          call: (p) async {
            calls.add(p);
            return {'policy': null};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls.single, {'action': 'commission_policy', 'storeRef': 'store'});
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
  testWidgets('unknown save retries same request and expected version', (
    tester,
  ) async {
    final writes = <Map<String, dynamic>>[];
    Future<Map<String, dynamic>> call(Map<String, dynamic> p) async {
      if (p['action'] == 'commission_policy_set') {
        writes.add(Map.of(p));
        throw Exception('timeout');
      }
      return {
        'policy': {'ref': 'previous-version', 'platformBps': 3000},
      };
    }

    await tester.pumpWidget(
      app(PartnerPolicyPage(storeRef: 'store', call: call)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(writes.length, 2);
    expect(writes[0], writes[1]);
    expect(writes[0]['expectedRef'], 'previous-version');
  });
  testWidgets('reversed commission displays origin and refund state', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        PartnerTasksPage(
          kind: 'ledger',
          call: (_) async => {
            'pendingCents': '0',
            'availableCents': '0',
            'items': [
              {
                'ref': 'booking:organizer',
                'title': 'Test store',
                'kind': 'organizer',
                'amountCents': '3200',
                'eligibleCents': '40000',
                'rateBps': 800,
                'status': 'reversed',
                'reversedAt': '2026-10-07',
                'date': '2026-10-06',
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('带局提成'), 200);
    expect(find.text('有效消费 ¥400.00 · 8.0%'), findsOneWidget);
    expect(find.textContaining('已退款冲回'), findsOneWidget);
    expect(find.textContaining('可提现日期'), findsNothing);
  });
}
