import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/partners/presentation/partner_platform_page.dart';
import 'package:kingclub/src/features/partners/presentation/partner_tasks_page.dart';
import 'package:kingclub/src/features/partners/data/partner_repository.dart';

Map<String, dynamic> context({
  bool admin = false,
  List<String> permissions = const [],
}) => {
  'partner': {'status': 'active', 'level': 5, 'organizerBps': 1000},
  'application': null,
  'profile': {'name': '测试合作者', 'memberId': 'KM123'},
  'finance': {
    'currency': 'CNY',
    'monthlyCents': '128000',
    'availableCents': '98000',
    'pendingCents': '36000',
  },
  'stores': [],
  'teamCount': 2,
  'customerCount': 3,
  'isAdmin': admin,
  'permissions': permissions,
};
Widget app(Widget home) => MaterialApp(
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData.dark(),
  home: home,
);
void main() {
  test('granular grant does not imply superadmin', () {
    final d = PartnerContext(context(permissions: ['withdrawals.review']));
    expect(d.can('withdrawals.review'), isTrue);
    expect(d.can('tasks.publish'), isFalse);
    expect(d.admin, isFalse);
  });
  testWidgets(
    'personal dashboard uses identity and actual monthly amount, without management',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(PartnerPlatformPage(call: (_) async => context())),
      );
      await tester.pumpAndSettle();
      expect(find.text('测试合作者'), findsOneWidget);
      expect(find.text('合作者'), findsOneWidget);
      expect(find.text('¥1,280.00'), findsOneWidget);
      expect(find.text('¥980.00'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('本月已入账收益 · CNY')).dy,
        lessThan(tester.getTopLeft(find.text('领取任务')).dy),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -550));
      await tester.pumpAndSettle();
      expect(find.text('我的团队'), findsOneWidget);
      expect(find.text('任务记录'), findsOneWidget);
      expect(find.text('平台管理'), findsNothing);
      expect(find.text('提现审核'), findsNothing);
    },
  );
  testWidgets(
    'delegated manager sees only authorized management below personal panel',
    (tester) async {
      await tester.pumpWidget(
        app(
          PartnerPlatformPage(
            call: (_) async => context(permissions: ['withdrawals.review']),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('提现审核'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('平台管理'), findsOneWidget);
      expect(find.text('权限管理'), findsNothing);
      expect(find.text('任务发布管理'), findsNothing);
      expect(find.text('合作申请审核'), findsNothing);
    },
  );
  testWidgets('claiming feed never offers create even for management account', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      app(
        PartnerTasksPage(
          call: (p) async {
            requests.add(p);
            return {'items': [], 'canCreate': true, 'isAdmin': true};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests.single['mode'], 'available');
    expect(find.text('创建任务'), findsNothing);
  });
  testWidgets('publisher and merchant use separate management modes', (
    tester,
  ) async {
    for (final store in [null, 'qa-store']) {
      final requests = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        app(
          PartnerTasksPage(
            key: ValueKey(store),
            management: true,
            storeRef: store,
            call: (p) async {
              requests.add(p);
              return {'items': [], 'canCreate': true};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.single['mode'], store == null ? 'manage' : 'merchant');
      expect(find.text('创建任务'), findsOneWidget);
      expect(find.text('任务发布管理'), findsOneWidget);
    }
  });
}
