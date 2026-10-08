import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/partners/presentation/partner_collaborator_detail_page.dart';
import 'package:kingclub/src/features/partners/presentation/partner_customer_directory_page.dart';
import 'package:kingclub/src/features/partners/presentation/collaborator_components.dart';
import 'package:kingclub/src/features/partners/presentation/partner_assignment_page.dart';
import 'package:kingclub/src/features/home/data/home_city_catalog.dart';

Map<String, dynamic> partner() => {
  'ref': 'U00000000002',
  'memberId': 'KMTEST2',
  'name': '合作者测试',
  'partnerRole': 'regional',
  'partnerLevel': 15,
  'levelName': '青铜 L-0',
  'phone': '13900000002',
  'city': '株洲市',
  'coverageCity': '株洲市',
  'status': 'active',
  'introduction': '组织活动经验',
};
Map<String, dynamic> overview() => {
  'partner': partner(),
  'finance': {
    'currency': 'CNY',
    'cumulativeCents': '123456789',
    'availableCents': '6000',
    'pendingCents': '5000',
    'frozenCents': '3000',
    'paidCents': '3000',
    'transferredCents': '4000',
    'commissionCents': '11000',
    'rewardCents': '10000',
    'monthlyCents': '21000',
  },
  'stats': {
    'teamCount': 2,
    'memberCount': 3,
    'taskCount': 7,
    'completedCount': 4,
  },
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
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => HomeCityCatalog.load());
  testWidgets(
    'superadmin assigns province, retries same uncertain request and updates overview without rereading',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        app(
          PartnerAssignmentPage(
            partner: {...partner(), 'roleVersion': 2},
            call: (p) async {
              calls.add(Map.of(p));
              throw Exception('uncertain');
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('assignment-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('省级合作者').last);
      await tester.pumpAndSettle();
      expect(find.text('选择省份'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('assignment-region')));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('assignment-province-list')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('湖南省'),
        400,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('assignment-province-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(find.text('湖南省'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('湖南省'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('assignment-reason')),
        '负责湖南地区',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('assignment-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assignment-save')));
      await tester.pumpAndSettle();
      expect(calls.single['role'], 'provincial');
      expect(calls.single['coverageCode'], '430000');
      expect(calls.single['expectedVersion'], 2);
      await tester.ensureVisible(find.byKey(const ValueKey('assignment-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assignment-save')));
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      expect(calls.last, calls.first);
    },
  );
  testWidgets(
    'directory shows partner grade and identity, then opens dedicated one-call overview',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        app(
          PartnerCustomerDirectoryPage(
            partnersOnly: true,
            call: (p) async {
              calls.add(p);
              return p['action'] == 'partners_directory'
                  ? {
                      'items': [partner()],
                      'total': 1,
                    }
                  : overview();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('L15'), findsOneWidget);
      expect(find.text('区域合作者'), findsOneWidget);
      expect(find.text('青铜 L-0'), findsNothing);
      await tester.tap(find.text('合作者测试'));
      await tester.pumpAndSettle();
      expect(find.text('合作者信息管理'), findsOneWidget);
      expect(find.text('顾客信息管理'), findsNothing);
      expect(find.text('¥1,234,567.89'), findsOneWidget);
      expect(calls.length, 2);
      expect(calls.last, {
        'action': 'collaborator_detail',
        'targetAccount': 'U00000000002',
        'tab': 'overview',
        'page': 0,
      });
    },
  );
  testWidgets(
    'overview entry opens paginated target withdrawals, no banking recipient data',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        app(
          PartnerCollaboratorDetailPage(
            targetAccount: 'U00000000002',
            call: (p) async {
              calls.add(p);
              return p['tab'] == 'overview'
                  ? overview()
                  : {
                      'items': [
                        {
                          'ref': 'withdrawal-test',
                          'amountCents': '3000',
                          'currency': 'CNY',
                          'status': 'paid',
                          'proofRef': 'test-proof',
                        },
                      ],
                      'total': 1,
                    };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('collaborator-withdrawals')),
        400,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('collaborator-withdrawals')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('collaborator-withdrawals')));
      await tester.pumpAndSettle();
      expect(calls.last['tab'], 'withdrawals');
      expect(calls.last['targetAccount'], 'U00000000002');
      expect(find.text('¥30.00'), findsOneWidget);
      expect(find.text('已打款'), findsOneWidget);
      expect(find.text('test-proof'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'permission read failure offers retry and never shows fabricated zero earnings',
    (tester) async {
      await tester.pumpWidget(
        app(
          PartnerCollaboratorDetailPage(
            targetAccount: 'U00000000002',
            call: (p) async => throw Exception('forbidden'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂时无法读取，请重试'), findsOneWidget);
      expect(find.text('¥0.00'), findsNothing);
    },
  );
  for (final locale in const [
    Locale('zh', 'CN'),
    Locale('en'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('th'),
  ]) {
    testWidgets('partner overview and lists fit 320dp at 200% in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          PartnerCollaboratorDetailPage(
            targetAccount: 'U00000000002',
            call: (p) async => overview(),
          ),
          locale: locale,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        app(
          PartnerCollaboratorDetailPage(
            key: const ValueKey('members'),
            targetAccount: 'U00000000002',
            section: 'team',
            call: (p) async => {
              'items': [partner()],
            },
          ),
          locale: locale,
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  test('every collaborator label has four translations', () {
    for (final value in collaboratorCopy.values) {
      expect(value.split('|').length, 4);
      expect(value.split('|').every((v) => v.isNotEmpty), isTrue);
    }
  });
}
