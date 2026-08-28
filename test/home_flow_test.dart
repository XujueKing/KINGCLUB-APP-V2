import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/home/presentation/home_page.dart';

void main() {
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
        ),
      ),
    );
  }

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
    expect(find.text('谁是最帅小哥哥'), findsOneWidget);
    expect(find.text('AI 卡颜局'), findsOneWidget);

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
    final scale = (393 - 32) / 680;

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
    await tester.ensureVisible(semanticsLabel('生日有礼'));
    final controller = tester.widget<CustomScrollView>(scrollable).controller!;
    final before = controller.offset;
    await tester.tap(semanticsLabel('生日有礼'));
    await tester.pumpAndSettle();
    expect(find.text('生日会员权益展示。当前仅模拟旧版内容阅读流程，不发放真实权益。'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    final after = controller.offset;
    expect(after, closeTo(before, .1));
  });

  testWidgets('member variants use legacy images and stay bounded', (
    tester,
  ) async {
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
    expect(progressRect.width / logoRect.width, closeTo(360 / 140, .01));
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

  testWidgets('loading empty partial offline and fatal states recover', (
    tester,
  ) async {
    await tester.pumpWidget(home(state: HomeDemoState.initialLoading));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(find.text('一起玩'), findsOneWidget);

    await tester.pumpWidget(home(state: HomeDemoState.emptyPromotion));
    await tester.pump();
    expect(find.byKey(const ValueKey('home-empty-promotions')), findsOneWidget);
    expect(find.text('一起玩'), findsOneWidget);
    await tester.tap(find.text('恢复 Fake 内容'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('home-empty-promotions')), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
    await tester.pump();
    expect(find.text('谁是最帅小哥哥'), findsOneWidget);

    await tester.pumpWidget(home(state: HomeDemoState.partialImageError));
    await tester.pump();
    expect(semanticsLabel('运营 Banner 加载失败'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await tester.pump();
    expect(semanticsLabel('生日有礼 图片加载失败'), findsOneWidget);
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
    expect(find.text('谁是最帅小哥哥'), findsOneWidget);

    await tester.pumpWidget(home(state: HomeDemoState.fatalError));
    await tester.pump();
    expect(find.text('首页暂时无法显示'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-fatal-retry')));
    await tester.pump();
    expect(find.text('一起玩'), findsOneWidget);
  });

  testWidgets('article and video promotion modes stay local and read only', (
    tester,
  ) async {
    await tester.pumpWidget(home(state: HomeDemoState.articleCard));
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await tester.pump();
    expect(semanticsLabel('图文内容，谁是最帅小哥哥，阿澈发布，128 次浏览'), findsOneWidget);

    await tester.pumpWidget(home(state: HomeDemoState.videoCard));
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await tester.pump();
    expect(semanticsLabel('视频内容，已暂停，静音'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('home-video-toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-video-toggle')));
    await tester.tap(find.byKey(const ValueKey('home-video-sound')));
    await tester.pump();
    expect(semanticsLabel('视频内容，正在播放，有声'), findsOneWidget);
  });

  testWidgets('refresh keeps content and session invalid resets safely', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(home());
    await tester.pump();
    tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pump();
    expect(find.text('正在刷新，当前内容继续保留'), findsOneWidget);
    expect(find.text('谁是最帅小哥哥'), findsOneWidget);
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
