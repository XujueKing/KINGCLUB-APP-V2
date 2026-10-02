import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/home/presentation/home_page.dart';
import 'package:kingclub/src/features/home/data/home_city_catalog.dart';
import 'package:kingclub/src/features/home/data/home_content_repository.dart';

import 'home_content_repository_test.dart'
    show homeFixture, homeSession, envelope;

void main() {
  setUpAll(() async => HomeCityCatalog.load());
  Finder semanticsLabel(String label) => find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );

  Widget home({
    HomeDemoState state = HomeDemoState.ready,
    int reselectSignal = 0,
    VoidCallback? onTogether,
    VoidCallback? onParty,
    VoidCallback? onScan,
    VoidCallback? onSessionReset,
    double textScale = 1,
    bool disableAnimations = false,
    Future<String?> Function()? locateCity,
    HomeContentRepository? repository,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: KingTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: HomePage(
          initialState: state,
          reselectSignal: reselectSignal,
          onOpenTogether: onTogether ?? () {},
          onOpenParty: onParty ?? () {},
          onOpenScanner: onScan ?? () {},
          onSessionResetRequested: onSessionReset,
          locateCity: locateCity ?? () async => null,
          repository: repository,
        ),
      ),
    );
  }

  testWidgets(
    'city defaults to location and late location does not replace a selection',
    (tester) async {
      final location = Completer<String?>();
      await tester.pumpWidget(home(locateCity: () => location.future));
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('home-city-selector')));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-city-input')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('home-city-input')),
        '长沙市',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('home-city-430100')));
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      location.complete('株洲市');
      await tester.pumpAndSettle();
      expect(find.text('长沙'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('home-city-selector')));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('株洲').first);
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('株洲'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('city initially uses the actual located city', (tester) async {
    await tester.pumpWidget(home(locateCity: () async => '株洲市'));
    await tester.pump();
    expect(find.text('株洲市'), findsOneWidget);
  });

  testWidgets('late old-city content cannot overwrite a newly selected city', (
    tester,
  ) async {
    final location = Completer<String?>();
    final oldCity = Completer<Map<String, dynamic>>();
    var oldCityReads = 0;
    final repository = HomeContentRepository(
      readSession: () async => homeSession('fixture'),
      request: (id, params, actor) async {
        final city = params['cityCode'];
        if (city == '430200') {
          oldCityReads++;
          return oldCity.future;
        }
        return envelope({
          'cityCode': city,
          'items': city == '430100' ? [homeFixture(ref: 'new-city')] : [],
        });
      },
    );
    await tester.pumpWidget(
      home(repository: repository, locateCity: () => location.future),
    );
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump();
    location.complete('株洲市');
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(oldCityReads, greaterThan(0));
    await tester.runAsync(
      () async => tester.tap(find.byKey(const ValueKey('home-city-selector'))),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('home-city-input')), '长沙');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-city-430100')));
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-card-new-city')), findsOneWidget);
    oldCity.complete(
      envelope({
        'cityCode': '430200',
        'items': [homeFixture(ref: 'old-city')],
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-card-old-city')), findsNothing);
    expect(find.byKey(const ValueKey('home-card-new-city')), findsOneWidget);
  });

  testWidgets('failed content refresh keeps artwork without an error row', (
    tester,
  ) async {
    var calls = 0;
    final repository = HomeContentRepository(
      readSession: () async => homeSession('fixture'),
      request: (id, params, actor) async {
        calls++;
        throw StateError('offline');
      },
    );
    await tester.pumpWidget(home(repository: repository));
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(0));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('home-card-legacy_handsome')),
      findsOneWidget,
    );
    expect(find.text('内容更新失败，点击重试'), findsNothing);
    await tester.runAsync(
      () async => tester.tap(find.byKey(const ValueKey('home-city-selector'))),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('home-city-input')), '长沙');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-city-430100')));
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('home-card-legacy_handsome')),
      findsOneWidget,
    );
    expect(find.text('内容更新失败，点击重试'), findsNothing);
  });

  testWidgets('ready home keeps legacy content and deduplicates actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var together = 0;
    var party = 0;
    var scans = 0;
    await tester.pumpWidget(
      home(
        onTogether: () => together += 1,
        onParty: () => party += 1,
        onScan: () => scans += 1,
      ),
    );
    await tester.pump();

    expect(find.text('青铜'), findsOneWidget);
    expect(find.text('L-0 EXP:50'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('一起玩'), findsOneWidget);
    expect(find.text('组局玩'), findsOneWidget);
    expect(find.text('SCAN QR'), findsOneWidget);
    expect(semanticsLabel('谁是最帅小哥哥'), findsOneWidget);
    expect(semanticsLabel('AI 卡颜局'), findsOneWidget);

    await tester.tap(find.text('一起玩'));
    await tester.tap(find.text('一起玩'));
    await tester.pump(const Duration(milliseconds: 310));
    await tester.tap(find.text('组局玩'));
    await tester.tap(find.text('组局玩'));
    await tester.pump(const Duration(milliseconds: 310));
    await tester.tap(find.text('SCAN QR'));
    await tester.tap(find.text('SCAN QR'));
    await tester.pump(const Duration(milliseconds: 310));
    expect((together, party, scans), (1, 1, 1));
  });

  testWidgets('quick actions keep legacy ratios typography shine and press', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(home());
    await tester.pump();

    final together = find.byKey(const ValueKey('home-quick-together'));
    final party = find.byKey(const ValueKey('home-quick-party'));
    final scan = find.byKey(const ValueKey('home-quick-scan'));
    final scale = 393 / 750;

    expect(tester.getSize(together).width, closeTo(246 * scale, .2));
    expect(tester.getSize(party).width, closeTo(246 * scale, .2));
    expect(tester.getSize(scan).width, closeTo(160 * scale, .2));
    expect(tester.getSize(together).height, closeTo(140 * scale, .2));
    expect(tester.getTopLeft(together).dy, tester.getTopLeft(scan).dy);
    expect(tester.getBottomRight(together).dy, tester.getBottomRight(scan).dy);

    final chinese = tester.widget<Text>(find.text('一起玩'));
    final english = tester.widget<Text>(find.text('TOGETHER PLAY'));
    expect(chinese.style?.fontSize, closeTo(38 * scale, .01));
    expect(chinese.style?.fontWeight, FontWeight.w600);
    expect(english.style?.fontSize, closeTo(20 * scale, .01));
    expect(english.style?.fontWeight, FontWeight.w400);

    final shine = find.byKey(const ValueKey('home-quick-shine-together'));
    await tester.pump(const Duration(milliseconds: 1));
    final before = tester.widget<CustomPaint>(shine).painter;
    await tester.pump(const Duration(milliseconds: 180));
    final after = tester.widget<CustomPaint>(shine).painter;
    expect(after, isNot(same(before)));
    expect(
      find.byKey(const ValueKey('home-quick-shine-party')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-quick-shine-scan')), findsOneWidget);

    tester.widget<InkWell>(together).onHighlightChanged!(true);
    await tester.pump(const Duration(milliseconds: 90));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('home-quick-opacity-together')),
          )
          .opacity,
      .7,
    );
    tester.widget<InkWell>(together).onHighlightChanged!(false);
    await tester.pump(const Duration(milliseconds: 90));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('home-quick-opacity-together')),
          )
          .opacity,
      1,
    );
  });

  testWidgets('campaign preview closes back to the same scroll position', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(home());
    await tester.pump();

    final scrollable = find.byType(CustomScrollView);
    await tester.drag(scrollable, const Offset(0, -280));
    await tester.pumpAndSettle();
    await tester.drag(scrollable, const Offset(0, -260));
    await tester.pumpAndSettle();
    final controller = tester.widget<CustomScrollView>(scrollable).controller!;
    final before = controller.offset;
    await tester.tap(semanticsLabel('生日有礼'));
    await tester.pumpAndSettle();
    expect(find.text('生日有礼'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    final after = controller.offset;
    expect(after, closeTo(before, .1));
  });

  testWidgets('member variants use legacy images and stay bounded', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    bool asset(String name, Widget widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName.endsWith(name);

    await tester.pumpWidget(home(state: HomeDemoState.verifiedMember));
    await tester.pump();
    expect(
      find.byWidgetPredicate((widget) => asset('man4.png', widget)),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((widget) => asset('bigV.png', widget)),
      findsOneWidget,
    );
    final logoRect = tester.getRect(
      find.byKey(const ValueKey('home-member-logo')),
    );
    final goldRect = tester.getRect(
      find.byKey(const ValueKey('home-member-asset-gold')),
    );
    final diamondRect = tester.getRect(
      find.byKey(const ValueKey('home-member-asset-diamond')),
    );
    final progressRect = tester.getRect(
      find.byKey(const ValueKey('home-member-progress')),
    );
    final viewportWidth = tester.getSize(find.byType(HomePage)).width;
    expect(logoRect.width / viewportWidth, closeTo(140 / 750, .001));
    expect(logoRect.height / logoRect.width, closeTo(213 / 400, .001));
    expect(progressRect.width / logoRect.width, closeTo(255 / 140, .01));
    expect(progressRect.right, closeTo(diamondRect.right, .1));
    expect(goldRect.width / logoRect.width, closeTo(120 / 140, .01));
    expect(goldRect.height / logoRect.width, closeTo(26 / 140, .01));
    expect(diamondRect.width, closeTo(goldRect.width, .01));
    expect(diamondRect.height, closeTo(goldRect.height, .01));

    await tester.pumpWidget(home(state: HomeDemoState.unspecifiedGender));
    await tester.pump();
    expect(semanticsLabel('未指定性别'), findsOneWidget);

    await tester.pumpWidget(
      home(state: HomeDemoState.longNickname, textScale: 2),
    );
    await tester.pump();
    expect(find.text('这是一个用于验证安全截断的很长昵称'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(home(state: HomeDemoState.largeBalance));
    await tester.pump();
    expect(find.text('12.8万'), findsOneWidget);
    expect(find.text('9.9万'), findsOneWidget);
  });

  testWidgets('member header shrinks and stays pinned while ads scroll', (
    tester,
  ) async {
    // A short viewport provides enough scroll range to fully collapse the
    // header even after removing the legacy page's excess vertical whitespace.
    await tester.binding.setSurfaceSize(const Size(393, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(home());
    await tester.pump();

    const headerKey = ValueKey('home-member-persistent-header');
    const logoKey = ValueKey('home-member-logo');
    final expandedHeader = tester.getRect(find.byKey(headerKey));
    final expandedLogo = tester.getRect(find.byKey(logoKey));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    final compactHeader = tester.getRect(find.byKey(headerKey));
    final compactLogo = tester.getRect(find.byKey(logoKey));
    final shadowFinder = find.byKey(
      const ValueKey('home-sticky-actions-shadow'),
    );
    final pinnedActions = tester.getRect(shadowFinder);
    final shadow = tester.widget<Container>(shadowFinder);
    expect(compactHeader.top, closeTo(expandedHeader.top, .1));
    expect(compactHeader.height, lessThan(expandedHeader.height));
    expect(compactLogo.width / expandedLogo.width, closeTo(.92, .001));
    expect(compactLogo.bottom, lessThanOrEqualTo(compactHeader.bottom));
    expect(
      // The member gradient extends 30rpx beyond the content, overlapping
      // the next layer without changing the actual 20rpx content gap.
      pinnedActions.top - compactHeader.bottom + 30 * 393 / 750,
      closeTo(20 * 393 / 750, .1),
    );
    expect((shadow.decoration! as BoxDecoration).boxShadow, isNotEmpty);
    expect(find.text('一起玩'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.getRect(shadowFinder).top, closeTo(pinnedActions.top, .1));

    tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!
        .jumpTo(0);
    await tester.pump();
    expect(
      tester.getRect(find.byKey(headerKey)).height,
      closeTo(expandedHeader.height, .1),
    );
    expect(
      tester.getRect(find.byKey(logoKey)).width,
      closeTo(expandedLogo.width, .1),
    );
  });

  testWidgets('loading empty partial offline and fatal states recover', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(home(state: HomeDemoState.initialLoading));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(find.text('一起玩'), findsOneWidget);

    await tester.pumpWidget(home(state: HomeDemoState.emptyPromotion));
    await tester.pump();
    expect(find.byKey(const ValueKey('home-empty-promotions')), findsOneWidget);
    expect(find.text('一起玩'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('home-empty-promotions')), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
    await tester.pump();
    expect(semanticsLabel('谁是最帅小哥哥'), findsOneWidget);

    await tester.pumpWidget(home(state: HomeDemoState.partialImageError));
    await tester.pump();
    expect(semanticsLabel('运营 Banner 加载失败'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(semanticsLabel('生日有礼'), findsOneWidget);
    tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!
        .jumpTo(0);
    await tester.pump();
    await tester.tap(find.text('查看文字详情').first);
    await tester.pump();
    expect(semanticsLabel('运营 Banner 加载失败'), findsNothing);

    await tester.pumpWidget(home(state: HomeDemoState.offlineCached));
    await tester.pump();
    expect(semanticsLabel('离线内容 · 最近更新 5 分钟前'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -360));
    await tester.pump();
    expect(semanticsLabel('谁是最帅小哥哥'), findsOneWidget);

    await tester.pumpWidget(home(state: HomeDemoState.fatalError));
    await tester.pump();
    expect(find.text('首页暂时无法显示'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-fatal-retry')));
    await tester.pump();
    expect(find.text('一起玩'), findsOneWidget);
  });

  testWidgets('refresh keeps content and session invalid resets safely', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(home());
    await tester.pump();
    final logo = find.byKey(const ValueKey('home-member-logo'));
    final initialY = tester.getTopLeft(logo).dy;
    final gesture = await tester.startGesture(const Offset(190, 300));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 220));
    await tester.pump();
    expect(tester.getTopLeft(logo).dy, greaterThan(initialY + 20));
    await gesture.up();
    await tester.pump();
    expect(semanticsLabel('谁是最帅小哥哥'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));

    var resets = 0;
    await tester.pumpWidget(
      home(
        state: HomeDemoState.sessionInvalid,
        onSessionReset: () => resets += 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('登录状态已失效'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-session-reset')));
    await tester.pumpAndSettle();
    expect(resets, 1);
  });

  testWidgets(
    'reselect scrolls home to top and reduced motion stops carousel',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(home(disableAnimations: true));
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!
            .offset,
        greaterThan(0),
      );
      await tester.pumpWidget(home(reselectSignal: 1, disableAnimations: true));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!
            .offset,
        0,
      );
      await tester.pump(const Duration(seconds: 5));
      expect(
        find.byKey(const ValueKey('home-banner-indicator-0-true')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-quick-shine-together')),
        findsNothing,
      );
    },
  );

  testWidgets('banner loops only to the left and rejects rightward paging', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(home());
    await tester.pump();

    final pages = find.byKey(const ValueKey('home-banner-pages'));
    PageController controller() => tester.widget<PageView>(pages).controller!;

    expect(controller().page, 10000);
    expect(
      find.byKey(const ValueKey('home-banner-legacy_recruitment')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('home-banner-legacy_childrens_day')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller().page, 10001);
    expect(
      find.byKey(const ValueKey('home-banner-legacy_childrens_day')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('home-banner-indicator-1-true')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller().page, 10002);
    expect(
      find.byKey(const ValueKey('home-banner-indicator-0-true')),
      findsOneWidget,
    );

    await tester.drag(pages, const Offset(-240, 0));
    await tester.pumpAndSettle();
    expect(controller().page, 10003);

    await tester.drag(pages, const Offset(240, 0));
    await tester.pumpAndSettle();
    expect(controller().page, 10003);
  });

  for (final size in [
    const Size(360, 800),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets('home core actions fit $size at 200% text', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(home(textScale: 2, disableAnimations: true));
      await tester.pump();
      expect(find.text('一起玩'), findsOneWidget);
      expect(find.text('组局玩'), findsOneWidget);
      expect(find.text('SCAN QR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
