import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/home/presentation/home_city_page.dart';
import 'package:kingclub/src/features/home/data/home_city_catalog.dart';
import 'package:flutter/material.dart';
import 'package:kingclub/src/core/design_system/king_keyboard_dismiss.dart';
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
    child: KingKeyboardDismiss(child: child!),
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
  testWidgets(
    'application verifies KM referrer and sends selected recommendation',
    (tester) async {
      HomeCitySession.current = const HomeCity(
        code: '430200',
        name: '株洲市',
        shortName: '株洲',
        pinyin: 'zhuzhou',
      );
      addTearDown(() => HomeCitySession.current = null);
      final requests = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        app((p) async {
          requests.add(Map.of(p));
          if (p['action'] == 'referrer') {
            return {
              'referrer': {
                'memberId': 'KM123',
                'name': 'Test referrer',
                'level': 7,
              },
            };
          }
          return snapshot();
        }),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('申请成为合作者').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('partner-referrer-input')),
        'km123',
      );
      await tester.tap(find.text('核对推荐人'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Test referrer'), findsOneWidget);
      await tester.ensureVisible(find.text('组织派对'));
      await tester.tap(find.text('组织派对'));
      await tester.scrollUntilVisible(
        find.text('提交申请'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('提交申请'));
      await tester.pumpAndSettle();
      expect(
        requests.where((p) => p['action'] == 'referrer').single['memberId'],
        'KM123',
      );
      expect(
        requests
            .where((p) => p['action'] == 'apply')
            .single['referrerMemberId'],
        'KM123',
      );
    },
  );
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
    expect(find.text('申请成为合作者'), findsNothing);
  });
  testWidgets(
    'unapproved member sees application, no commission or directory',
    (tester) async {
      await tester.pumpWidget(app((_) async => snapshot()));
      await tester.pumpAndSettle();
      expect(find.text('申请成为合作者'), findsWidgets);
      expect(find.text('分佣账户'), findsNothing);
      expect(find.text('客户名录'), findsNothing);
    },
  );
  testWidgets(
    'approved dashboard has no invented money and hides admin entry',
    (tester) async {
      await tester.pumpWidget(app((_) async => snapshot(approved: true)));
      await tester.pumpAndSettle();
      expect(find.text('本月已入账收益 · CNY'), findsOneWidget);
      expect(find.textContaining('1,280'), findsNothing);
      expect(find.text('客户名录'), findsNothing);
      expect(find.textContaining('带局提成'), findsNothing);
      expect(find.text('合作等级 L5'), findsOneWidget);
    },
  );
  testWidgets('merchant entry is not duplicated on partner page', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        (_) async => {
          ...snapshot(),
          'stores': [
            {'ref': 'test', 'name': '测试门店'},
          ],
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('切换身份'), findsNothing);
    expect(find.text('商家平台'), findsNothing);
  });
  testWidgets('application city uses home selector and returns chosen city', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.runAsync(() => HomeCityCatalog.load());
    HomeCitySession.current = const HomeCity(
      code: '430200',
      name: '株洲市',
      shortName: '株洲',
      pinyin: 'zhuzhou',
    );
    addTearDown(() => HomeCitySession.current = null);
    await tester.pumpWidget(app((_) async => snapshot()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('申请成为合作者').last);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('partner-city-choice')));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.byType(HomeCityPage), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('home-city-input')),
      '北京市',
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('北京市').last);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.byType(HomeCityPage), findsNothing);
    expect(find.text('北京市'), findsOneWidget);
  });
  testWidgets('retry preserves submitted application request id', (
    tester,
  ) async {
    HomeCitySession.current = const HomeCity(
      code: '430200',
      name: '株洲市',
      shortName: '株洲',
      pinyin: 'zhuzhou',
    );
    addTearDown(() => HomeCitySession.current = null);
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
    await tester.tap(find.text('申请成为合作者').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('partner-city-choice')), findsOneWidget);
    expect(find.text('株洲市'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.tap(find.text('组织派对'));
    await tester.scrollUntilVisible(
      find.text('提交申请'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('重试'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(submitted.length, 2);
    expect(submitted.first['city'], '株洲市');
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
