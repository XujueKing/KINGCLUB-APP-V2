import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/scanner/presentation/safe_scanner_page.dart';

void main() {
  Widget scanner({
    SafeScannerDemoState state = SafeScannerDemoState.rationale,
    ValueChanged<SafeScanDestination>? onResolved,
    VoidCallback? onClose,
    VoidCallback? onSessionReset,
    double textScale = 1,
    bool disableAnimations = false,
    Duration delay = const Duration(milliseconds: 30),
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
      home: SafeScannerPage(
        initialState: state,
        fakeDelay: delay,
        onClose: onClose ?? () {},
        onResolved: onResolved ?? (_) {},
        onSessionResetRequested: onSessionReset,
      ),
    );
  }

  Future<void> openCamera(WidgetTester tester) async {
    await tester.ensureVisible(find.text('开始扫码'));
    await tester.tap(find.text('开始扫码'));
    await tester.pump(const Duration(milliseconds: 35));
    expect(find.text('将二维码放入框内'), findsOneWidget);
  }

  Future<void> expandScenarios(WidgetTester tester) async {
    await tester.ensureVisible(find.text('展开 UI 测试场景'));
    await tester.tap(find.text('展开 UI 测试场景'));
    await tester.pump();
  }

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('rationale requests only Fake permission and controls torch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(scanner());

    expect(find.text('只识别 KingClub 可信场景'), findsOneWidget);
    expect(find.textContaining('二维码原文不会展示'), findsOneWidget);
    await openCamera(tester);
    expect(find.text('FAKE CAMERA'), findsOneWidget);
    expect(find.byTooltip('打开手电筒'), findsOneWidget);
    await tester.tap(find.byTooltip('打开手电筒'));
    await tester.pump();
    expect(find.byTooltip('关闭手电筒'), findsOneWidget);
  });

  testWidgets('temporary permission denial retries without a request loop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      scanner(state: SafeScannerDemoState.permissionDenied),
    );
    expect(find.text('暂时无法使用相机'), findsOneWidget);
    await tester.ensureVisible(find.text('再次请求'));
    await tester.tap(find.text('再次请求'));
    await tester.pump(const Duration(milliseconds: 35));
    expect(find.text('将二维码放入框内'), findsOneWidget);
  });

  testWidgets('permanent denial exposes settings simulation and safe return', (
    tester,
  ) async {
    var closes = 0;
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      scanner(
        state: SafeScannerDemoState.permissionPermanentlyDenied,
        onClose: () => closes += 1,
      ),
    );
    expect(find.text('请在系统设置中允许相机'), findsOneWidget);
    await tester.ensureVisible(find.text('返回原页面'));
    await tester.tap(find.text('返回原页面'));
    expect(closes, 1);
  });

  for (final destination in SafeScanDestination.values) {
    testWidgets('${destination.name} emits one typed intent only', (
      tester,
    ) async {
      final results = <SafeScanDestination>[];
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(scanner(onResolved: results.add));
      await openCamera(tester);
      await expandScenarios(tester);
      final scenarioLabel = switch (destination) {
        SafeScanDestination.friendProfile => '好友资料',
        SafeScanDestination.tableOrdering => '桌台点单',
        SafeScanDestination.admissionContext => '入场凭证',
      };
      await tester.ensureVisible(find.text(scenarioLabel));
      await tester.tap(find.text(scenarioLabel));
      await tester.pump(const Duration(milliseconds: 35));
      final enter = find.text('进入${destination.label}');
      await tester.ensureVisible(enter);
      await tester.tap(enter);
      await tester.tap(enter);
      expect(results, [destination]);
      expect(find.textContaining('不会直接执行'), findsOneWidget);
    });
  }

  testWidgets(
    'unsupported expired and offline states fail closed and recover',
    (tester) async {
      for (final entry in <SafeScannerDemoState, String>{
        SafeScannerDemoState.unsupported: '不支持此二维码',
        SafeScannerDemoState.expiredOrUsed: '二维码已失效或已使用',
        SafeScannerDemoState.recoverableError: '暂时无法完成校验',
      }.entries) {
        await tester.pumpWidget(
          scanner(state: entry.key, disableAnimations: true),
        );
        await tester.pump();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('在浏览器打开'), findsNothing);
        final retry = find.text('重新扫码').last;
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        await tester.pump();
        expect(find.text('将二维码放入框内'), findsOneWidget);
      }
    },
  );

  testWidgets('single flight and close invalidate late resolver results', (
    tester,
  ) async {
    final results = <SafeScanDestination>[];
    var closes = 0;
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      scanner(
        delay: const Duration(milliseconds: 100),
        onResolved: results.add,
        onClose: () => closes += 1,
      ),
    );
    await tester.tap(find.text('开始扫码'));
    await tester.pump(const Duration(milliseconds: 110));
    await expandScenarios(tester);
    await tester.ensureVisible(find.text('好友资料'));
    await tester.tap(find.text('好友资料'));
    await tester.tap(find.text('桌台点单'));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tap(find.byTooltip('关闭扫码'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(closes, 1);
    expect(results, isEmpty);
    expect(find.text('识别成功'), findsNothing);
  });

  testWidgets('session invalid clears the flow and requests auth reset', (
    tester,
  ) async {
    var resets = 0;
    await tester.pumpWidget(
      scanner(
        state: SafeScannerDemoState.sessionInvalid,
        onSessionReset: () => resets += 1,
      ),
    );
    expect(find.text('登录状态已失效'), findsOneWidget);
    expect(find.textContaining('识别内容已清理'), findsOneWidget);
    await tester.ensureVisible(find.text('返回登录'));
    await tester.tap(find.text('返回登录'));
    expect(resets, 1);
  });

  testWidgets('background pauses camera and disables torch until resume', (
    tester,
  ) async {
    await tester.pumpWidget(scanner(state: SafeScannerDemoState.cameraActive));
    await tester.tap(find.byTooltip('打开手电筒'));
    await tester.pump();
    expect(find.byTooltip('关闭手电筒'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('扫码已暂停'), findsOneWidget);
    expect(find.byTooltip('打开手电筒'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('扫码已暂停'), findsNothing);
  });

  for (final size in [
    const Size(360, 800),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets('scanner is reachable at $size with 200% text', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(scanner(textScale: 2, disableAnimations: true));
      await tester.ensureVisible(find.text('开始扫码'));
      expect(find.text('开始扫码'), findsOneWidget);
      expect(
        tester
            .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
            .every((widget) => widget.duration == Duration.zero),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
