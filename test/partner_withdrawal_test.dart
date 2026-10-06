import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/partners/presentation/partner_withdrawal_page.dart';

Widget app(Widget p) => MaterialApp(
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData.dark(),
  home: p,
);
Map<String, dynamic> state() => {
  'userAccount': 'U00000000001',
  'availableCents': '10000',
  'items': [],
};
void main() {
  testWidgets(
    'application requires recipient and persists uncertain request across reopening',
    (t) async {
      FlutterSecureStorage.setMockInitialValues({});
      final writes = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> call(Map<String, dynamic> p) async {
        if (p['action'] == 'withdrawal_list') return state();
        writes.add(Map.of(p));
        throw Exception('timeout');
      }

      await t.pumpWidget(app(PartnerWithdrawalPage(call: call)));
      await t.pumpAndSettle();
      await t.tap(find.text('申请提现'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(0), '12.34');
      await t.enterText(find.byType(TextField).at(1), 'Synthetic');
      await t.enterText(find.byType(TextField).at(2), 'SYNTHETIC-ACCOUNT');
      await t.ensureVisible(find.text('确认'));
      await t.tap(find.text('确认'));
      await t.pumpAndSettle();
      expect(writes.single['amountCents'], 1234);
      expect(writes.single['channel'], 'bank');
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(app(PartnerWithdrawalPage(call: call)));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('核对本次转账'));
      await t.tap(find.text('核对本次转账'));
      await t.pumpAndSettle();
      expect(writes.length, 2);
      expect(writes[0], writes[1]);
    },
  );
  testWidgets(
    'approved withdrawal is shown as waiting, never paid without evidence',
    (t) async {
      FlutterSecureStorage.setMockInitialValues({});
      final calls = <Map<String, dynamic>>[];
      await t.pumpWidget(
        app(
          PartnerWithdrawalPage(
            review: true,
            call: (p) async {
              calls.add(p);
              return {
                ...state(),
                'items': [
                  {
                    'ref': 'test',
                    'partnerAccount': 'U00000000002',
                    'amountCents': '6000',
                    'channel': 'bank',
                    'payeeName': 'Synthetic',
                    'payeeAccount': 'TEST',
                    'status': 'approved',
                    'date': '2026-10-07',
                  },
                ],
              };
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('待人工打款'), findsOneWidget);
      expect(find.text('已支付'), findsNothing);
      await t.ensureVisible(find.text('登记付款凭证'));
      await t.tap(find.text('登记付款凭证'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('确认'));
      await t.tap(find.text('确认'));
      await t.pumpAndSettle();
      expect(calls.length, 1);
      expect(t.takeException(), isNull);
    },
  );
}
