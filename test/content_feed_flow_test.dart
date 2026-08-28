import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/content/presentation/content_feed_page.dart';

Widget _app(
  ContentFeedDemoState state, {
  bool active = true,
  ValueChanged<String>? onOpenAuthor,
  VoidCallback? onReturnHome,
  VoidCallback? onSessionResetRequested,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: KingTheme.dark,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: ContentFeedPage(
        key: ValueKey('content-${state.name}-$active-$textScale'),
        active: active,
        initialState: state,
        onOpenAuthor: onOpenAuthor ?? (_) {},
        onReturnHome: onReturnHome,
        onSessionResetRequested: onSessionResetRequested,
      ),
    ),
  );
}

void main() {
  testWidgets('normal feed is muted, read only and opens safe author ref', (
    tester,
  ) async {
    String? authorRef;
    await tester.pumpWidget(
      _app(
        ContentFeedDemoState.content,
        onOpenAuthor: (value) => authorRef = value,
      ),
    );
    expect(find.text('静音'), findsOneWidget);
    expect(find.text('发布'), findsNothing);
    expect(find.text('点赞'), findsNothing);
    expect(find.text('评论'), findsNothing);
    expect(find.text('收藏'), findsNothing);
    expect(find.byIcon(Icons.science_outlined), findsNothing);
    await tester.tap(find.text('NEON 阿澈'));
    expect(authorRef, 'social-target-neon');
  });

  testWidgets('empty and initial error recover safely', (tester) async {
    var returned = false;
    await tester.pumpWidget(
      _app(ContentFeedDemoState.empty, onReturnHome: () => returned = true),
    );
    expect(find.text('暂时没有新作品'), findsOneWidget);
    await tester.tap(find.text('返回首页'));
    expect(returned, isTrue);

    await tester.pumpWidget(_app(ContentFeedDemoState.initialError));
    expect(find.text('内容加载失败'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('NEON 阿澈'), findsOneWidget);
  });

  testWidgets('refresh and pagination preserve current work', (tester) async {
    await tester.pumpWidget(_app(ContentFeedDemoState.refreshing));
    expect(find.text('正在刷新，当前作品已暂停'), findsOneWidget);
    expect(find.text('NEON 阿澈'), findsOneWidget);

    await tester.pumpWidget(_app(ContentFeedDemoState.loadingMore));
    expect(find.text('正在加载更多作品'), findsOneWidget);
    expect(find.text('NEON 阿澈'), findsOneWidget);

    await tester.pumpWidget(_app(ContentFeedDemoState.loadMoreError));
    expect(find.text('更多作品加载失败，当前作品仍可浏览'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(find.text('正在播放'), findsOneWidget);
  });

  testWidgets('buffer, media error and removal never auto advance', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ContentFeedDemoState.buffering));
    expect(find.text('正在缓冲'), findsOneWidget);
    expect(find.text('NEON 阿澈'), findsOneWidget);

    await tester.pumpWidget(_app(ContentFeedDemoState.mediaError));
    expect(find.text('当前作品播放失败'), findsOneWidget);
    await tester.tap(find.text('重试当前作品'));
    await tester.pump();
    expect(find.text('正在播放'), findsOneWidget);

    await tester.pumpWidget(_app(ContentFeedDemoState.unavailable));
    expect(find.text('内容暂不可用'), findsOneWidget);
    expect(find.text('周末组局官'), findsNothing);
  });

  testWidgets('poster-only and hidden author do not leak or write', (
    tester,
  ) async {
    var authorOpenCount = 0;
    await tester.pumpWidget(_app(ContentFeedDemoState.posterOnly));
    expect(find.text('低流量 · 封面模式'), findsOneWidget);
    final muteButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '静音'),
    );
    expect(muteButton.onPressed, isNull);

    await tester.pumpWidget(
      _app(
        ContentFeedDemoState.authorUnavailable,
        onOpenAuthor: (_) => authorOpenCount++,
      ),
    );
    await tester.tap(find.text('NEON 阿澈'));
    await tester.pump();
    expect(find.text('作者资料暂不可见'), findsOneWidget);
    expect(authorOpenCount, 0);
  });

  testWidgets('inactive branch and app background stay paused', (tester) async {
    await tester.pumpWidget(_app(ContentFeedDemoState.content, active: false));
    expect(find.text('已暂停'), findsOneWidget);

    await tester.pumpWidget(_app(ContentFeedDemoState.content));
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.pump();
    expect(find.text('已暂停'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  testWidgets('200 percent text remains inside a scrollable feed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(ContentFeedDemoState.content, textScale: 2));
    expect(tester.takeException(), isNull);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('NEON 阿澈'), findsOneWidget);
  });

  testWidgets('session invalid releases content and requests login reset', (
    tester,
  ) async {
    var reset = false;
    await tester.pumpWidget(
      _app(
        ContentFeedDemoState.sessionInvalid,
        onSessionResetRequested: () => reset = true,
      ),
    );
    await tester.pump();
    expect(find.text('已停止播放并清除当前作品引用，请重新登录。'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('content-feed-session-confirm')),
    );
    await tester.pumpAndSettle();
    expect(reset, isTrue);
    expect(find.text('NEON 阿澈'), findsNothing);
  });
}
