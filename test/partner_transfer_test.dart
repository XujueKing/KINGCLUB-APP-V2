import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/partners/presentation/partner_transfer_page.dart';
import 'package:kingclub/src/features/partners/presentation/partner_strings.dart';

Widget app(Widget p) => MaterialApp(
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData.dark(),
  home: p,
);
Map<String, dynamic> state() => {
  'userAccount': 'U00000000001',
  'currency': 'CNY',
  'canTransfer': 1,
  'availableCents': '10000',
  'pendingCents': '1000',
  'cashCents': '5000',
  'items': [],
};
void main() {
  test('all partner text contains four nonempty translations', () {
    for (final e in partnerCopy.entries) {
      expect(e.value.split('|').length, 4, reason: e.key);
      expect(
        e.value.split('|').every((v) => v.trim().isNotEmpty),
        isTrue,
        reason: e.key,
      );
    }
  });
  testWidgets(
    'unknown transfer is persisted and retried with identical amount and request after reopening',
    (t) async {
      FlutterSecureStorage.setMockInitialValues({});
      final writes = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> call(Map<String, dynamic> p) async {
        if (p['action'] == 'finance') return state();
        writes.add(Map.of(p));
        throw Exception('connection lost');
      }

      await t.pumpWidget(app(PartnerTransferPage(call: call)));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '12.34');
      await t.ensureVisible(find.byType(FilledButton));
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
      await t.tap(find.text('确认'));
      await t.pumpAndSettle();
      expect(writes.single['amountCents'], 1234);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(app(PartnerTransferPage(call: call)));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(FilledButton));
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
      expect(writes.length, 2);
      expect(writes[0], writes[1]);
    },
  );
  testWidgets('over available input is capped before confirmation', (t) async {
    FlutterSecureStorage.setMockInitialValues({});
    final calls = <Map<String, dynamic>>[];
    await t.pumpWidget(
      app(
        PartnerTransferPage(
          call: (p) async {
            calls.add(p);
            return state();
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '100.01');
    await t.ensureVisible(find.byType(FilledButton));
    await t.tap(find.byType(FilledButton));
    await t.pumpAndSettle();
    expect(calls.length, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      '100.00',
    );
  });
}
