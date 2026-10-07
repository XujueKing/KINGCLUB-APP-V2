import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/partners/presentation/customer_components.dart';
import 'package:kingclub/src/features/partners/presentation/partner_customer_directory_page.dart';
import 'package:kingclub/src/features/partners/presentation/partner_customer_detail_page.dart';

Map<String, dynamic> customer() => {
  'ref': 'U00000000002',
  'memberId': 'KMTEST2',
  'name': '测试会员',
  'realName': '测试姓名',
  'gender': 1,
  'levelName': '黄金 L-1',
  'phone': '13900000002',
  'date': '2026-10-07 04:00:00',
  'birthDate': '1990-09-05',
  'age': 36,
  'status': 'active',
  'registrationStatus': 'approved',
  'appearanceVersion': 3,
  'assets': {'cashCents': '123450', 'coins': '1692', 'diamonds': '0'},
  'stats': {
    'orderCount': 1,
    'friendCount': 2,
    'messageCount': 518,
    'teamCount': 0,
  },
  'appearance': {'score': 78, 'selfie': 77, 'portrait': 78, 'outfit': 79},
  'preferences': {
    'styles': ['cosplay'],
  },
};
Map<String, dynamic> directory(String name) => {
  'items': [
    {...customer(), 'name': name},
  ],
  'total': 1,
  'hasMore': false,
};
Widget app(
  Widget home, {
  Locale locale = const Locale('zh', 'CN'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [
    Locale('zh', 'CN'),
    Locale('en'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('th'),
  ],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData.dark(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);
Map<String, dynamic> profile() => {
  'customer': customer(),
  'canSetStatus': true,
  'consumption': [
    {'currency': 'CNY', 'amountCents': '33000'},
  ],
  'commissionCents': '1650',
  'storeBalances': [
    {'store': '测试门店', 'currency': 'CNY', 'amountCents': '220000'},
  ],
};
void main() {
  testWidgets('phone copy stays next to the number and vertically centered', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        PartnerCustomerDetailPage(
          targetAccount: 'U00000000002',
          call: (_) async => profile(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final number = tester.getRect(
      find.byKey(const ValueKey('customer-phone-number')),
    );
    final copy = tester.getRect(
      find.byKey(const ValueKey('customer-phone-copy')),
    );
    expect((number.center.dy - copy.center.dy).abs(), lessThan(1));
    expect(copy.left - number.right, inInclusiveRange(0, 8));
    expect(copy.height, greaterThanOrEqualTo(44));
  });
  testWidgets(
    'pending member switch approves frozen photos and updates from the same reply',
    (tester) async {
      final p = profile();
      (p['customer'] as Map)['registrationStatus'] = 'pending_review';
      p.addAll({'canSetStatus': false, 'canReview': true, 'canApprove': true});
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        app(
          PartnerCustomerDetailPage(
            targetAccount: 'U00000000002',
            call: (input) async {
              calls.add(Map.of(input));
              if (input['action'] == 'customer_status')
                return {
                  'status': 'active',
                  'registrationStatus': 'approved',
                  'canSetStatus': true,
                };
              return p;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('customer-status'));
      await tester.scrollUntilVisible(toggle, 300);
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(find.text('待人工审核'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('通过会员审核'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('customer-status-reason')),
        '人工审核通过',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      final input = calls.last;
      expect(input['status'], 'approved');
      expect(input['expectedRegistrationStatus'], 'pending_review');
      expect(input['expectedAppearanceVersion'], 3);
      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(find.text('正常'), findsOneWidget);
      expect(
        calls.where((input) => input['action'] == 'customer_detail').length,
        1,
      );
    },
  );
  testWidgets(
    'unready member cannot use the approval switch and readers have no switch',
    (tester) async {
      for (final canReview in [true, false]) {
        final p = profile();
        (p['customer'] as Map)['registrationStatus'] = 'pending_review';
        p.addAll({
          'canSetStatus': false,
          'canReview': canReview,
          'canApprove': false,
        });
        await tester.pumpWidget(
          app(
            PartnerCustomerDetailPage(
              key: ValueKey(canReview),
              targetAccount: 'U00000000002',
              call: (_) async => p,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (canReview) {
          final toggle = find.byKey(const ValueKey('customer-status'));
          await tester.scrollUntilVisible(toggle, 300);
          expect(tester.widget<Switch>(toggle).onChanged, isNull);
        } else {
          expect(find.byKey(const ValueKey('customer-status')), findsNothing);
        }
      }
    },
  );
  testWidgets(
    'stale manual approval reloads pending state without pretending approval',
    (tester) async {
      Map<String, dynamic> pending() {
        final p = profile();
        (p['customer'] as Map)['registrationStatus'] = 'pending_review';
        return {
          ...p,
          'canSetStatus': false,
          'canReview': true,
          'canApprove': true,
        };
      }

      var reads = 0;
      await tester.pumpWidget(
        app(
          PartnerCustomerDetailPage(
            targetAccount: 'U00000000002',
            call: (input) async {
              if (input['action'] == 'customer_status')
                throw StateError('stale photo version');
              reads++;
              return pending();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('customer-status'));
      await tester.scrollUntilVisible(toggle, 300);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('customer-status-reason')),
        '人工审核',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(toggle, 300);
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(reads, 2);
    },
  );
  test('all customer interface copy has four translations', () {
    for (final v in customerCopy.values) {
      expect(v.split('|').length, 4);
      expect(v.split('|').every((x) => x.isNotEmpty), isTrue);
    }
  });
  testWidgets(
    'category switch ignores old request and search preserves filters',
    (tester) async {
      final old = Completer<Map<String, dynamic>>(),
          calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        app(
          PartnerCustomerDirectoryPage(
            call: (p) async {
              calls.add(p);
              return calls.length == 1 ? old.future : directory('新分类');
            },
          ),
        ),
      );
      await tester.tap(find.text('合作者'));
      await tester.pumpAndSettle();
      old.complete(directory('旧分类'));
      await tester.pumpAndSettle();
      expect(find.textContaining('旧分类'), findsNothing);
      expect(find.textContaining('新分类'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('customer-search')),
        'KMTEST2',
      );
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(calls.last, containsPair('category', 'marketing'));
      expect(calls.last, containsPair('query', 'KMTEST2'));
      expect(calls.last, containsPair('page', 0));
    },
  );
  testWidgets(
    'member opens full information then ledger and append-only notes',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> call(Map<String, dynamic> p) async {
        calls.add(Map.of(p));
        if (p['action'] == 'directory') return directory('测试会员');
        if (p['tab'] == 'profile') return profile();
        if (p['action'] == 'customer_note') {
          return {
            'record': {
              'ref': p['requestId'],
              'content': p['content'],
              'type': 'note',
              'operator': '测试管理员',
              'date': '2026-10-07T04:00:00Z',
            },
          };
        }
        return {'items': [], 'total': 0};
      }

      await tester.pumpWidget(app(PartnerCustomerDirectoryPage(call: call)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('customer-U00000000002')));
      await tester.pumpAndSettle();
      expect(find.text('顾客信息管理'), findsOneWidget);
      expect(find.textContaining('KMTEST2'), findsOneWidget);
      expect(find.text('¥330.00'), findsOneWidget);
      await tester.tap(find.text('账目'));
      await tester.pumpAndSettle();
      expect(calls.last['tab'], 'ledger');
      expect(calls.last.containsKey('month'), isTrue);
      await tester.tap(find.text('备注'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('customer-note')),
        '需要靠近舞台的座位',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('customer-save-note')));
      await tester.pumpAndSettle();
      expect(find.text('需要靠近舞台的座位'), findsOneWidget);
      expect(find.text('测试管理员'), findsOneWidget);
      expect(
        calls
            .where((p) => p['action'] == 'customer_note')
            .single['targetAccount'],
        'U00000000002',
      );
    },
  );
  testWidgets(
    'uncertain note save retries the same request without duplicate record',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        app(
          PartnerCustomerDetailPage(
            targetAccount: 'U00000000002',
            call: (p) async {
              if (p['tab'] == 'profile') return profile();
              if (p['action'] == 'customer_note') {
                requests.add(Map.of(p));
                if (requests.length == 1) throw StateError('lost reply');
                return {
                  'record': {
                    'ref': p['requestId'],
                    'type': 'note',
                    'content': p['content'],
                    'operator': 'Operator',
                    'date': '2026-10-07T04:00:00Z',
                  },
                };
              }
              return {'items': [], 'total': 0};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('备注'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('customer-note')),
        'Note',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('customer-save-note')));
      await tester.pumpAndSettle();
      expect(find.text('保存未确认，请重试'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(requests[0]['requestId'], requests[1]['requestId']);
      expect(find.text('Note'), findsOneWidget);
    },
  );
  testWidgets('a delayed note reply never appears in the ledger tab', (
    tester,
  ) async {
    final saved = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      app(
        PartnerCustomerDetailPage(
          targetAccount: 'U00000000002',
          call: (p) async {
            if (p['tab'] == 'profile') return profile();
            if (p['action'] == 'customer_note') return saved.future;
            return {'items': [], 'total': 0};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('备注'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('customer-note')),
      'Delayed note',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customer-save-note')));
    await tester.pump();
    await tester.tap(find.text('账目'));
    await tester.pumpAndSettle();
    saved.complete({
      'record': {
        'ref': 'note-1',
        'type': 'note',
        'content': 'Delayed note',
        'operator': 'Operator',
        'date': '2026-10-07T04:00:00Z',
      },
    });
    await tester.pumpAndSettle();
    expect(find.text('Delayed note'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('directory read error does not pretend there are no members', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        PartnerCustomerDirectoryPage(
          call: (_) async => throw StateError('forbidden'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂时无法读取，请重试'), findsOneWidget);
    expect(find.text('暂无记录'), findsNothing);
  });
  for (final locale in const [
    Locale('zh', 'CN'),
    Locale('en'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('th'),
  ]) {
    testWidgets('customer pages fit large text in $locale', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Future<Map<String, dynamic>> call(Map<String, dynamic> p) async =>
          p['action'] == 'directory' ? directory('测试会员') : profile();
      await tester.pumpWidget(
        app(
          PartnerCustomerDirectoryPage(call: call),
          locale: locale,
          scale: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('customer-U00000000002')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
