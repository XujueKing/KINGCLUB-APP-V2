import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kingclub/src/core/design_system/king_back_gesture.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/messaging/data/call_presentation_lease.dart';
import 'package:kingclub/src/features/messaging/presentation/call_presentation_scope.dart';

Future<void> swipe(WidgetTester tester, {double distance = 300}) async {
  await tester.timedDragFrom(
    const Offset(5, 250),
    Offset(distance, 0),
    const Duration(milliseconds: 900),
  );
  await tester.pumpAndSettle();
}

Future<NavigatorState> openPage(
  WidgetTester tester,
  Widget page, {
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  final key = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: key,
      theme: KingTheme.dark.copyWith(platform: platform),
      home: const Scaffold(body: Text('origin')),
    ),
  );
  key.currentState!.push<void>(KingPageRoute(builder: (_) => page));
  await tester.pumpAndSettle();
  return key.currentState!;
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform interactive swipe can cancel and then return', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final nav = await openPage(
        tester,
        const Scaffold(body: Text('detail')),
        platform: platform,
      );
      final route = ModalRoute.of(tester.element(find.text('detail')))!;
      final drag = await tester.startGesture(const Offset(5, 250));
      await drag.moveBy(const Offset(70, 0));
      await tester.pump();
      expect(nav.userGestureInProgress, isTrue);
      expect(route.animation!.value, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 500));
      await drag.up();
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);
      expect(route.animation!.value, 1);
      expect(nav.userGestureInProgress, isFalse);
      await swipe(tester);
      expect(find.text('detail'), findsNothing);
      expect(find.text('origin'), findsOneWidget);
    });
  }

  testWidgets(
    'guarded swipe asks before discarding and never bypasses PopScope',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var attempts = 0;
      await openPage(
        tester,
        Builder(
          builder: (context) => PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              attempts++;
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('discard draft?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('keep editing'),
                    ),
                  ],
                ),
              );
            },
            child: const Scaffold(body: Text('draft')),
          ),
        ),
      );
      await swipe(tester, distance: 60);
      expect(attempts, 0);
      await swipe(tester);
      expect(attempts, 1);
      expect(find.text('discard draft?'), findsOneWidget);
      await swipe(tester);
      expect(attempts, 1);
      await tester.tap(find.text('keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('draft'), findsOneWidget);
    },
  );

  testWidgets('internal history closes first, next swipe returns the page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var removed = false;
    await openPage(tester, const Scaffold(body: Text('detail')));
    ModalRoute.of(
      tester.element(find.text('detail')),
    )!.addLocalHistoryEntry(LocalHistoryEntry(onRemove: () => removed = true));
    await tester.pump();
    await swipe(tester);
    expect(removed, true);
    expect(find.text('detail'), findsOneWidget);
    await swipe(tester);
    expect(find.text('origin'), findsOneWidget);
  });

  testWidgets('middle paging and edge vertical scroll do not return', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openPage(
      tester,
      Scaffold(
        body: PageView(
          children: [
            ListView(children: [for (var i = 0; i < 40; i++) Text('row $i')]),
            const Center(child: Text('second page')),
          ],
        ),
      ),
    );
    await tester.dragFrom(const Offset(5, 250), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsOneWidget);
    await tester.dragFrom(const Offset(300, 250), const Offset(-260, 0));
    await tester.pumpAndSettle();
    expect(find.text('second page'), findsOneWidget);
    await tester.dragFrom(const Offset(100, 250), const Offset(260, 0));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('root page does not exit on a swipe', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        home: const Scaffold(body: Text('root')),
      ),
    );
    await swipe(tester, distance: 650);
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('go replacement step uses controlled back without popping root', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late GoRouter router;
    var backs = 0;
    router = GoRouter(
      initialLocation: '/step',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('welcome')),
        ),
        GoRoute(
          path: '/step',
          builder: (_, _) => PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                backs++;
                router.go('/');
              }
            },
            child: const KingEdgeBackGesture(
              allowRoot: true,
              child: Scaffold(body: Text('step')),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: KingTheme.dark, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await swipe(tester, distance: 60);
    expect(backs, 0);
    await swipe(tester);
    expect(backs, 1);
    expect(find.text('welcome'), findsOneWidget);
  });

  testWidgets('hosted call swipe minimizes without ending capture', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lease = CallPresentationLease.acquire()!;
    await tester.pumpWidget(
      MaterialApp(
        theme: KingTheme.dark,
        builder: (_, child) => CallPresentationHost(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => pushCallPresentation(
                Navigator.of(context),
                Builder(
                  builder: (context) {
                    final controls = CallPresentationControls.of(context)!;
                    controls.onBack = controls.minimize;
                    return controls.minimized
                        ? CallMiniWindow(
                            title: 'call',
                            status: 'active',
                            onRestore: controls.restore,
                            onHangUp: controls.close,
                          )
                        : const Scaffold(body: Text('full call'));
                  },
                ),
                lease,
              ),
              child: const Text('open call'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open call'));
    await tester.pumpAndSettle();
    await swipe(tester);
    expect(find.text('full call'), findsNothing);
    expect(find.byType(CallMiniWindow), findsOneWidget);
    expect(CallPresentationLease.acquire(), isNull);
    await tester.tap(find.byKey(const ValueKey('call-restore')));
    await tester.pumpAndSettle();
    expect(find.text('full call'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    final next = CallPresentationLease.acquire();
    expect(next, isNotNull);
    next?.release();
  });
}
