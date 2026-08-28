import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/scanner/presentation/safe_scanner_page.dart';
import 'package:kingclub/src/features/shell/presentation/app_shell_page.dart';

void main() {
  Widget shell({
    int initialIndex = 0,
    AppShellDemoState state = AppShellDemoState.ready,
    Future<SafeScanDestination?> Function(BuildContext, int)? onOpenScanner,
    VoidCallback? onSessionResetRequested,
    VoidCallback? onMembershipReviewRequested,
    ValueChanged<int>? onDestinationReselected,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: KingTheme.dark,
      home: AppShellPage(
        key: ValueKey('$initialIndex-$state'),
        initialIndex: initialIndex,
        initialDemoState: state,
        onOpenScanner: onOpenScanner ?? (_, _) async => null,
        onOpenTogether: () {},
        onOpenParty: () {},
        onSessionResetRequested: onSessionResetRequested,
        onMembershipReviewRequested: onMembershipReviewRequested,
        onDestinationReselected: onDestinationReselected,
      ),
    );
  }

  testWidgets('five fixed destinations preserve and reselect message branch', (
    tester,
  ) async {
    var reselected = -1;
    await tester.pumpWidget(
      shell(onDestinationReselected: (index) => reselected = index),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('首页，标签，已选中'), findsOneWidget);
    expect(find.bySemanticsLabel('消息，标签，5 条未读'), findsOneWidget);
    expect(find.bySemanticsLabel('内容，标签'), findsOneWidget);
    expect(find.bySemanticsLabel('私人储物柜，标签'), findsOneWidget);
    expect(find.bySemanticsLabel('我的，标签'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('消息，标签，5 条未读'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('聊天'));
    await tester.pumpAndSettle();
    expect(find.text('KING CLUB'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('首页，标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('消息，标签，5 条未读'));
    await tester.pumpAndSettle();
    expect(find.text('KING CLUB'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('消息，标签，5 条未读，已选中'));
    await tester.pumpAndSettle();
    expect(find.text('通讯录'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('消息，标签，5 条未读，已选中'));
    await tester.pump();
    expect(reselected, 1);
  });

  testWidgets('scanner opening is deduplicated and preserves source branch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final result = Completer<SafeScanDestination?>();
    var openings = 0;
    await tester.pumpWidget(
      shell(
        initialIndex: 4,
        onOpenScanner: (_, originIndex) {
          openings += 1;
          expect(originIndex, 0);
          return result.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('首页，标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SCAN QR'));
    await tester.tap(find.text('SCAN QR'));
    await tester.pump();
    expect(openings, 1);

    result.complete(null);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.bySemanticsLabel('首页，标签，已选中'), findsOneWidget);
  });

  testWidgets('offline overlay preserves branch and can be dismissed', (
    tester,
  ) async {
    await tester.pumpWidget(
      shell(initialIndex: 2, state: AppShellDemoState.offline),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shell-offline-banner')), findsOneWidget);
    expect(find.bySemanticsLabel('内容，标签，已选中'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shell-offline-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shell-offline-banner')), findsNothing);
    expect(find.bySemanticsLabel('内容，标签，已选中'), findsOneWidget);
  });

  testWidgets('session and membership transitions block navigation and exit', (
    tester,
  ) async {
    var sessionReset = 0;
    await tester.pumpWidget(
      shell(
        initialIndex: 4,
        state: AppShellDemoState.sessionTransition,
        onSessionResetRequested: () => sessionReset += 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('shell-session-transition')),
      findsOneWidget,
    );
    await tester.tap(find.text('返回登录'));
    expect(sessionReset, 1);

    var reviewRequests = 0;
    await tester.pumpWidget(
      shell(
        state: AppShellDemoState.membershipTransition,
        onMembershipReviewRequested: () => reviewRequests += 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('shell-membership-transition')),
      findsOneWidget,
    );
    await tester.tap(find.text('查看审核状态'));
    expect(reviewRequests, 1);
  });

  testWidgets('Android root back returns a non-home branch to home', (
    tester,
  ) async {
    await tester.pumpWidget(shell(initialIndex: 4));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('我的，标签，已选中'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.bySemanticsLabel('首页，标签，已选中'), findsOneWidget);
  });

  for (final configuration in <(Size, double)>[
    (const Size(360, 800), 1),
    (const Size(393, 852), 1.3),
    (const Size(430, 932), 2),
  ]) {
    testWidgets(
      'navigation fits ${configuration.$1} at ${configuration.$2}x text',
      (tester) async {
        await tester.binding.setSurfaceSize(configuration.$1);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: KingTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(configuration.$2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: AppShellPage(
              initialIndex: 2,
              onOpenScanner: (_, _) async => null,
              onOpenTogether: () {},
              onOpenParty: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final label in ['首页', '消息', '内容', '私人储物柜', '我的']) {
          final destination = find.bySemanticsLabel(RegExp('^$label，标签'));
          expect(destination, findsOneWidget);
          final size = tester.getSize(destination);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
