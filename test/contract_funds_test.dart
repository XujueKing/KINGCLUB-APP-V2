import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/presentation/contract_fund_evidence_page.dart';
import 'package:kingclub/src/features/club/presentation/monthly_contracts_page.dart';

import 'monthly_contracts_test.dart' show page, terms;

void main() {
  testWidgets(
    'funded signing waits for actual funding and never opens publication',
    (t) async {
      final draft = {...terms(guarantee: 10000), 'canClaim': true};
      final calls = <Map<String, dynamic>>[];
      await page(
        t,
        MonthlyContractDetailPage(
          contractRef: draft['ref'] as String,
          call: (p) async {
            calls.add(p);
            return {
              'items': [
                p['action'] == 'claim'
                    ? {
                        ...draft,
                        'status': 'funding',
                        'canClaim': false,
                        'isMine': true,
                        'funds': [
                          {
                            'ref': 'test-fund',
                            'purpose': 'guarantee',
                            'amountCents': '10000',
                            'status': 'due',
                            'canPay': true,
                          },
                        ],
                      }
                    : draft,
              ],
            };
          },
          fundCall: (_) async => throw StateError('No payment expected'),
        ),
      );
      await t.scrollUntilVisible(
        find.byType(CheckboxListTile),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await t.tap(find.text('领取并签约'));
      await t.pumpAndSettle();
      expect(calls.length, 2);
      expect(find.text('待资金确认'), findsOneWidget);
      expect(find.text('发布本卡座AA邀请'), findsNothing);
    },
  );
  testWidgets(
    'only an authoritative query enables publication and uses returned page data',
    (t) async {
      final pending = {
        ...terms(guarantee: 10000),
        'status': 'funding',
        'canClaim': false,
        'isMine': true,
        'funds': [
          {
            'ref': 'test-fund',
            'purpose': 'guarantee',
            'amountCents': '10000',
            'status': 'paying',
            'canPay': true,
          },
        ],
      };
      final calls = <Map<String, dynamic>>[];
      await page(
        t,
        MonthlyContractDetailPage(
          contractRef: pending['ref'] as String,
          call: (_) async => {
            'items': [pending],
          },
          fundCall: (p) async {
            calls.add(p);
            return {
              'items': [
                {
                  ...pending,
                  'status': 'active',
                  'funds': [
                    {
                      'ref': 'test-fund',
                      'purpose': 'guarantee',
                      'amountCents': '10000',
                      'status': 'paid',
                      'channel': 'wechat',
                    },
                  ],
                },
              ],
            };
          },
        ),
      );
      await t.scrollUntilVisible(
        find.text('核对原付款'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('核对原付款'));
      await t.pumpAndSettle();
      await t.tap(find.text('核对原付款'));
      await t.pumpAndSettle();
      expect(calls.single, {
        'action': 'payment',
        'operation': 'query',
        'fundRef': 'test-fund',
      });
      expect(find.text('发布本卡座AA邀请'), findsOneWidget);
    },
  );
  testWidgets(
    'offline evidence retries exactly, keeps amount and original return channel fixed, and footer below keyboard',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetViewInsets);
      final calls = <Map<String, dynamic>>[];
      await page(
        t,
        ContractFundEvidencePage(
          fund: const {
            'ref': 'test-fund',
            'amountCents': '123456',
            'channel': 'bank',
          },
          returning: true,
          call: (p) async {
            calls.add(p);
            throw StateError('Network uncertain');
          },
        ),
      );
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('CNY 1,234.56'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'test-return-evidence');
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      final footer = t.getRect(find.text('确认登记'));
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      await t.pump();
      expect(t.getRect(find.text('确认登记')), footer);
      t.view.viewInsets = const FakeViewPadding();
      await t.pump();
      await t.tap(find.text('确认登记'));
      await t.pumpAndSettle();
      await t.tap(find.text('确认登记'));
      await t.pumpAndSettle();
      expect(calls.length, 2);
      expect(calls[0], calls[1]);
      expect(calls.first['amountCents'], 123456);
      expect(calls.first['channel'], 'bank');
      expect(calls.first['paidAt'], matches(RegExp(r'\.\d{3}Z$')));
    },
  );
}
