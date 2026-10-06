import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/partners/data/partner_repository.dart';
import 'package:kingclub/src/features/partners/presentation/partner_platform_page.dart';
import 'package:kingclub/src/features/partners/presentation/partner_strings.dart';

Map<String, dynamic> snapshot({bool approved = false, bool admin = false}) => {
  'partner': approved
      ? {'status': 'active', 'level': 5, 'organizerBps': 1000}
      : null,
  'application': null,
  'stores': <Map<String, dynamic>>[],
  'isAdmin': admin,
  'teamCount': 0,
  'customerCount': 0,
};
Widget app(
  PartnerCall call, {
  Locale locale = const Locale('zh', 'CN'),
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  supportedLocales: const [
    Locale('zh', 'CN'),
    Locale('en'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('th'),
  ],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData.dark(),
  home: PartnerPlatformPage(call: call),
);
void main() {
  test(
    'rejects inconsistent earnings level, never silently substitutes fee',
    () {
      expect(
        () => PartnerContext({
          ...snapshot(approved: true),
          'partner': {'status': 'active', 'level': 5, 'organizerBps': 2000},
        }),
        throwsFormatException,
      );
    },
  );
  test('all partner copy has four languages', () {
    for (final value in partnerCopy.values) {
      expect(value.split('|').length, 4);
      expect(value.split('|').every((s) => s.isNotEmpty), isTrue);
    }
  });
  testWidgets('unknown request failure is not displayed as no application', (
    tester,
  ) async {
    await tester.pumpWidget(app((_) async => throw StateError('offline')));
    await tester.pumpAndSettle();
    expect(find.text('暂时无法读取，请重试'), findsOneWidget);
    expect(find.text('申请成为合作伙伴'), findsNothing);
  });
  testWidgets(
    'unapproved member sees application, no commission or directory',
    (tester) async {
      await tester.pumpWidget(app((_) async => snapshot()));
      await tester.pumpAndSettle();
      expect(find.text('申请成为合作伙伴'), findsWidgets);
      expect(find.text('分佣账户'), findsNothing);
      expect(find.text('客户名录'), findsNothing);
    },
  );
  testWidgets(
    'approved dashboard has no invented money and hides admin entry',
    (tester) async {
      await tester.pumpWidget(app((_) async => snapshot(approved: true)));
      await tester.pumpAndSettle();
      expect(find.text('分佣账户'), findsOneWidget);
      expect(find.textContaining('1,280'), findsNothing);
      expect(find.text('客户名录'), findsNothing);
      expect(find.text('带局提成 10%'), findsOneWidget);
    },
  );
  testWidgets('merchant switch uses returned authorized stores', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      app((p) async {
        calls.add(p);
        if (p['action'] == 'merchant') {
          return {
            'store': {'name': '测试门店', 'address': '测试地址', 'currency': 'CNY'},
          };
        }
        return {
          ...snapshot(),
          'stores': [
            {'ref': 'test', 'name': '测试门店'},
          ],
        };
      }),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('切换身份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试门店'));
    await tester.pumpAndSettle();
    expect(calls.last, {'action': 'merchant', 'storeRef': 'test'});
    expect(find.text('商家平台'), findsOneWidget);
  });
  testWidgets('retry preserves submitted application request id', (
    tester,
  ) async {
    final submitted = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      app((p) async {
        if (p['action'] == 'apply') {
          submitted.add(Map.of(p));
          throw StateError('timeout');
        }
        return snapshot();
      }),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('申请成为合作伙伴').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '株洲');
    await tester.tap(find.text('组织派对'));
    await tester.ensureVisible(find.text('提交申请'));
    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(submitted.length, 2);
    expect(submitted[0], submitted[1]);
  });
  testWidgets('320dp layout and large text remain usable', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: app(
          (_) async => snapshot(approved: true),
          locale: const Locale('en'),
          textScale: 1.4,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
