import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/core/design_system/king_components.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/partners/presentation/partner_amount_field.dart';
import 'package:kingclub/src/features/partners/presentation/partner_withdrawal_page.dart';
import 'package:kingclub/src/features/partners/presentation/partner_withdrawal_history_page.dart';
import 'package:kingclub/src/features/partners/presentation/partner_transfer_page.dart';

Widget app(Widget home) => MaterialApp(
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: KingTheme.dark,
  home: home,
);
Map<String, dynamic> state() => {
  'userAccount': 'U00000000001',
  'availableCents': '123456',
  'canWithdraw': true,
  'cards': <Map<String, dynamic>>[],
};
void main() {
  test(
    'amount input caps exact cents including large pasted values and MAX limit',
    () {
      final formatter = PartnerAmountFormatter(123456);
      final old = const TextEditingValue();
      expect(
        formatter
            .formatEditUpdate(old, const TextEditingValue(text: '1234.57'))
            .text,
        '1,234.56',
      );
      expect(
        formatter
            .formatEditUpdate(
              old,
              const TextEditingValue(text: '9999999999999999999999'),
            )
            .text,
        '1,234.56',
      );
      expect(
        formatter
            .formatEditUpdate(old, const TextEditingValue(text: '1.'))
            .text,
        '1.',
      );
      expect(
        formatter
            .formatEditUpdate(old, const TextEditingValue(text: '1.234'))
            .text,
        '',
      );
      expect(partnerAmountCents('0.01'), 1);
      expect(partnerAmountCents('1,234.56'), 123456);
      expect(partnerAmountCents('1,23.45'), isNull);
      final grouped = formatter.formatEditUpdate(
        old,
        const TextEditingValue(
          text: '1234.50',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(grouped.text, '1,234.50');
      expect(grouped.selection.extentOffset, 8);
      expect(partnerAmountLimit('-1'), 0);
      expect(partnerAmountLimit('999999999999999'), 999999999);
    },
  );
  testWidgets(
    'shared toolbar overrides old black and title size without moving back target',
    (t) async {
      await t.pumpWidget(
        app(
          Builder(
            builder: (c) => Scaffold(
              backgroundColor: const Color(0xff111111),
              appBar: kingAppBar(
                context: c,
                title: const Text(
                  '合作者平台',
                  style: TextStyle(fontSize: 20, color: Colors.amber),
                ),
                backgroundColor: Colors.black,
                actions: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final bar = t.widget<AppBar>(find.byType(AppBar));
      final title = t.widget<Text>(find.text('合作者平台'));
      expect(bar.backgroundColor, Colors.transparent);
      expect(bar.scrolledUnderElevation, 0);
      expect(title.style!.fontSize, 17);
      expect(title.style!.fontWeight, FontWeight.w600);
      expect(title.style!.color, Colors.white);
      expect(
        t.getTopRight(find.byIcon(Icons.notifications_none)).dx,
        lessThan(t.view.physicalSize.width / t.view.devicePixelRatio - 18),
      );
    },
  );
  testWidgets(
    'saved card manager returns masked card and MAX fills balance without a history on the form',
    (t) async {
      FlutterSecureStorage.setMockInitialValues({});
      final writes = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> call(Map<String, dynamic> p) async {
        if (p['action'] == 'withdrawal_form') return state();
        writes.add(Map.of(p));
        return {
          ...state(),
          'receiptRef': p['requestId'],
          'cards': [
            {
              'ref': p['requestId'],
              'bankName': 'Synthetic bank',
              'accountMasked': '•••• 0001',
              'payeeName': 'Synthetic',
            },
          ],
        };
      }

      await t.pumpWidget(app(PartnerWithdrawalPage(call: call)));
      await t.pumpAndSettle();
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('提现明细'), findsNothing);
      await t.tap(find.text('添加银行卡'));
      await t.pumpAndSettle();
      await t.tap(find.text('添加银行卡'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(0), 'Synthetic');
      await t.enterText(find.byType(TextField).at(1), 'Synthetic bank');
      await t.enterText(find.byType(TextField).at(2), 'TEST00000001');
      await t.ensureVisible(find.text('保存银行卡'));
      await t.tap(find.text('保存银行卡'));
      await t.pumpAndSettle();
      expect(writes.single['action'], 'bank_card_add');
      expect(find.text('•••• 0001'), findsOneWidget);
      expect(find.text('TEST00000001'), findsNothing);
      await t.tap(find.byType(KingBackButton));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('partner-amount-max')));
      await t.tap(find.byKey(const ValueKey('partner-amount-max')));
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        '1,234.56',
      );
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(t.takeException(), isNull);
    },
  );
  for (final withdrawal in [true, false]) {
    testWidgets(
      '${withdrawal ? 'withdrawal' : 'transfer'} defaults to maximum, accepts manual amount and MAX restores maximum',
      (t) async {
        FlutterSecureStorage.setMockInitialValues({});
        final writes = <Map<String, dynamic>>[];
        Future<Map<String, dynamic>> call(Map<String, dynamic> p) async {
          if (['finance', 'withdrawal_form'].contains(p['action'])) {
            return {
              ...state(),
              'canTransfer': true,
              'cashCents': '0',
              'cards': [
                {
                  'ref': 'synthetic-card',
                  'bankName': 'Synthetic bank',
                  'accountMasked': '•••• 0001',
                },
              ],
            };
          }
          writes.add(Map.of(p));
          return {
            'receiptRef': p['requestId'],
            'receipt': {'ref': p['requestId']},
            'availableCents': '100006',
          };
        }

        await t.pumpWidget(
          app(
            withdrawal
                ? PartnerWithdrawalPage(call: call)
                : PartnerTransferPage(call: call),
          ),
        );
        await t.pumpAndSettle();
        final input = find.byKey(const ValueKey('partner-amount-input'));
        final field = t.widget<TextField>(input);
        expect(field.controller!.text, '1,234.56');
        expect(
          field.decoration!.floatingLabelBehavior,
          FloatingLabelBehavior.always,
        );
        await t.ensureVisible(input);
        await t.tap(input);
        await t.pump();
        expect(t.testTextInput.isVisible, isTrue);
        expect(
          field.keyboardType,
          const TextInputType.numberWithOptions(decimal: true),
        );
        await t.enterText(input, '234.50');
        await t.tap(find.byKey(const ValueKey('partner-amount-max')));
        await t.pump();
        expect(field.controller!.text, '1,234.56');
        await t.enterText(input, '234.50');
        await t.ensureVisible(find.byType(FilledButton));
        await t.tap(find.byType(FilledButton));
        await t.pumpAndSettle();
        expect(find.textContaining('¥234.50'), findsOneWidget);
        await t.tap(find.text('确认'));
        await t.pumpAndSettle();
        expect(writes.single['amountCents'], 23450);
        expect(field.controller!.text, '1,000.06');
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '${withdrawal ? 'withdrawal' : 'transfer'} shows zero amount without allowing a financial action',
      (t) async {
        FlutterSecureStorage.setMockInitialValues({});
        Future<Map<String, dynamic>> call(Map<String, dynamic> p) async => {
          ...state(),
          'availableCents': '0',
          'canTransfer': true,
          'cashCents': '0',
        };
        await t.pumpWidget(
          app(
            withdrawal
                ? PartnerWithdrawalPage(call: call)
                : PartnerTransferPage(call: call),
          ),
        );
        await t.pumpAndSettle();
        final field = t.widget<TextField>(
          find.byKey(const ValueKey('partner-amount-input')),
        );
        expect(field.controller!.text, '0.00');
        expect(find.text('0.00'), findsWidgets);
        expect(field.enabled, isFalse);
        expect(
          t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
      },
    );
  }
  testWidgets(
    'dedicated history contains both transfer and withdrawal, only submitted withdrawal can cancel',
    (t) async {
      FlutterSecureStorage.setMockInitialValues({});
      await t.pumpWidget(
        app(
          PartnerWithdrawalHistoryPage(
            call: (_) async => {
              'userAccount': 'U00000000001',
              'items': [
                {
                  'ref': 'a',
                  'kind': 'withdrawal',
                  'amountCents': '5000',
                  'status': 'submitted',
                  'date': '2030-01-01',
                },
                {
                  'ref': 'b',
                  'kind': 'transfer',
                  'amountCents': '10000',
                  'status': 'transferred',
                  'date': '2030-01-01',
                },
              ],
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('提现明细'), findsOneWidget);
      expect(find.text('撤销申请'), findsOneWidget);
      expect(find.text('转入平台余额'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
}
