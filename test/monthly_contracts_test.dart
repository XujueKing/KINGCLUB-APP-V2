import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_localizations.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/presentation/monthly_contracts_page.dart';

Map<String, dynamic> terms({int guarantee = 0}) => {
  'ref': '00000000-0000-4000-8000-000000000001',
  'storeRef': 'store-a',
  'storeName': 'Test store',
  'tableRef': 'v1',
  'tableName': 'V1',
  'capacity': 10,
  'title': 'Test monthly task',
  'description': 'Test conditions',
  'month': '2030-01',
  'timeZone': 'Asia/Shanghai',
  'status': 'published',
  'version': 2,
  'currency': 'CNY',
  'guaranteeCents': '$guarantee',
  'contractCents': '0',
  'collector': 'store',
  'goalBookings': 20,
  'goalRevenueCents': '1000000',
  'goalMode': 'all',
  'organizerBps': null,
  'effectiveOrganizerBps': null,
  'platformBps': null,
  'canClaim': guarantee == 0,
  'termsHash': 'a' * 64,
};
Future<void> page(WidgetTester t, Widget w, {Locale? locale}) async {
  await t.pumpWidget(
    MaterialApp(
      theme: KingTheme.dark,
      locale: locale ?? kingSupportedLocales.first,
      supportedLocales: kingSupportedLocales,
      localizationsDelegates: kingLocalizationDelegates,
      home: w,
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'funded contract displays separate amounts without signing or payment action',
    (t) async {
      var calls = 0;
      await page(
        t,
        MonthlyContractDetailPage(
          contractRef: terms()['ref'],
          call: (p) async {
            calls++;
            return {
              'items': [terms(guarantee: 10000)],
            };
          },
        ),
      );
      expect(calls, 1);
      expect(find.text('CNY 100.00'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
    },
  );
  testWidgets(
    'signing requires consent and retries the original request, displaying only returned state',
    (t) async {
      final calls = <Map<String, dynamic>>[];
      var attempts = 0;
      await page(
        t,
        MonthlyContractDetailPage(
          contractRef: terms()['ref'],
          call: (p) async {
            calls.add(p);
            if (p['action'] == 'detail')
              return {
                'items': [terms()],
              };
            if (++attempts == 1) throw StateError('Temporary failure');
            return {
              'items': [
                {
                  ...terms(),
                  'status': 'active',
                  'version': 3,
                  'canClaim': false,
                  'effectiveOrganizerBps': 1000,
                  'platformBps': 3000,
                },
              ],
            };
          },
        ),
      );
      expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, null);
      await t.scrollUntilVisible(
        find.byType(CheckboxListTile),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
      expect(find.text('已签约'), findsNothing);
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
      expect(calls.length, 3);
      expect(calls[1], calls[2]);
      expect(calls[1]['acceptedTerms'], true);
      expect(calls[1]['termsHash'], 'a' * 64);
      expect(find.text('已签约'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    },
  );
  testWidgets(
    'merchant editor shares workspace data and keyboard does not raise the footer',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetViewInsets);
      await page(
        t,
        MonthlyContractEditorPage(
          storeRef: 'store-a',
          workspace: {
            'store': {'timeZone': 'Asia/Shanghai'},
            'tables': [
              {'ref': 'v1', 'name': 'V1', 'capacity': 10},
            ],
          },
          call: (_) async => {},
        ),
      );
      final before = t.getTopLeft(find.byType(FilledButton)).dy;
      await t.tap(find.byType(TextField).first);
      await t.pump();
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      await t.pump();
      expect(t.getTopLeft(find.byType(FilledButton)).dy, before);
      expect(t.takeException(), null);
      await t.tap(find.text('整月签约任务'));
      await t.pump();
      expect(
        t
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        false,
      );
    },
  );
}
