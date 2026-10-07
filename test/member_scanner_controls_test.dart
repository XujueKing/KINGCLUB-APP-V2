import 'package:kingclub/src/features/scanner/data/cashier_login_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:kingclub/src/features/scanner/presentation/member_scanner_page.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';

class _Camera extends MobileScannerPlatform {
  int starts = 0, torches = 0;
  String? analyzed;
  BarcodeCapture? capture;
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    return MobileScannerViewAttributes(
      cameraDirection: options.cameraDirection,
      currentTorchMode: TorchState.off,
      size: Size(800, 600),
    );
  }

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.green);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> toggleTorch() async {
    torches++;
  }

  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const [],
  }) async {
    analyzed = path;
    return capture;
  }
}

class _Cashier implements CashierLoginRepository {
  @override
  Future<CashierLoginChallenge> inspect(String id) async =>
      CashierLoginChallenge(
        status: 'pending',
        deviceLabel: '测试收银机',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        stores: [const CashierLoginStore(ref: 'store', name: '测试门店')],
      );
  @override
  Future<String> approve(String id, String store) async => 'approved';
  @override
  Future<String> reject(String id) async => 'rejected';
}

void main() {
  for (final kind in ['P', 'M']) {
    testWidgets(
      'referrer $kind code picker returns to application without binding',
      (tester) async {
        final original = MobileScannerPlatform.instance;
        final code = 'KC:$kind:${'A' * 32}';
        final camera = _Camera()
          ..capture = BarcodeCapture(barcodes: [Barcode(rawValue: code)]);
        MobileScannerPlatform.instance = camera;
        addTearDown(() => MobileScannerPlatform.instance = original);
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => MemberScannerPage(
                          pickReferrer: true,
                          pickPhoto: () async => XFile('/test/referrer.png'),
                        ),
                      ),
                    );
                  },
                  child: const Text('申请页扫码'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('申请页扫码'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('相册'));
        await tester.pumpAndSettle();
        expect(selected, code);
        expect(find.byType(MemberScannerPage), findsNothing);
        expect(find.text('申请页扫码'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
  testWidgets('table scan replaces camera and Back returns to caller', (
    tester,
  ) async {
    final original = MobileScannerPlatform.instance;
    final camera = _Camera()
      ..capture = BarcodeCapture(
        barcodes: [Barcode(rawValue: 'type=9&tableId=V2')],
      );
    MobileScannerPlatform.instance = camera;
    addTearDown(() => MobileScannerPlatform.instance = original);
    var scannerOpening = false;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () async {
                if (scannerOpening) return;
                scannerOpening = true;
                await context.push('/scanner');
                scannerOpening = false;
              },
              child: const Text('打开扫码'),
            ),
          ),
        ),
        GoRoute(
          path: '/scanner',
          builder: (context, state) => MemberScannerPage(
            pickPhoto: () async => XFile('/test/table.png'),
          ),
        ),
        GoRoute(
          path: '/commerce/ordering',
          // Match the typed production ordering route's MaterialPage.
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            allowSnapshotting: false,
            child: Scaffold(
              body: TextButton(
                onPressed: () => context.pop(),
                child: Text('返回 ${state.uri.queryParameters['tableId']}'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: KingTheme.dark, routerConfig: router),
    );
    await tester.tap(find.text('打开扫码'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('相册'));
    await tester.pumpAndSettle();
    expect(find.text('返回 V2'), findsOneWidget);
    expect(find.byType(MemberScannerPage), findsNothing);
    final orderingRoute =
        ModalRoute.of(tester.element(find.text('返回 V2')))! as PageRoute;
    expect(orderingRoute.popGestureEnabled, true);
    final drag = await tester.startGesture(const Offset(5, 250));
    await drag.moveBy(const Offset(70, 0));
    await tester.pump();
    expect(orderingRoute.navigator!.userGestureInProgress, true);
    await drag.moveBy(const Offset(580, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.text('打开扫码'), findsOneWidget);
    expect(find.byType(MemberScannerPage), findsNothing);
    expect(scannerOpening, isFalse);
    await tester.tap(find.text('打开扫码'));
    await tester.pumpAndSettle();
    expect(find.byType(MemberScannerPage), findsOneWidget);
    await tester.tap(find.byTooltip('相册'));
    await tester.pumpAndSettle();
    expect(find.text('返回 V2'), findsOneWidget);
    await tester.tap(find.text('返回 V2'));
    await tester.pumpAndSettle();
    expect(find.text('打开扫码'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('cashier completion returns to scan origin and can scan again', (
    tester,
  ) async {
    final original = MobileScannerPlatform.instance;
    final camera = _Camera()
      ..capture = BarcodeCapture(
        barcodes: [
          Barcode(rawValue: 'kingclub://cashier-login/v1/${'a' * 64}'),
        ],
      );
    MobileScannerPlatform.instance = camera;
    addTearDown(() => MobileScannerPlatform.instance = original);
    var opening = false;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () async {
                if (opening) return;
                opening = true;
                await context.push('/scanner');
                opening = false;
              },
              child: const Text('原入口扫码'),
            ),
          ),
        ),
        GoRoute(
          path: '/scanner',
          builder: (_, _) => MemberScannerPage(
            pickPhoto: () async => XFile('/test/cashier.png'),
            cashierRepository: _Cashier(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: KingTheme.dark, routerConfig: router),
    );
    await tester.tap(find.text('原入口扫码'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('相册'));
    await tester.pumpAndSettle();
    expect(find.byType(MemberScannerPage), findsNothing);
    expect(opening, isFalse);
    await tester.tap(find.byKey(const ValueKey('cashier-login-approve')));
    await tester.pumpAndSettle();
    await tester.timedDragFrom(
      const Offset(5, 250),
      const Offset(650, 0),
      const Duration(milliseconds: 1800),
    );
    await tester.pumpAndSettle();
    expect(find.text('原入口扫码'), findsOneWidget);
    expect(find.byType(MemberScannerPage), findsNothing);
    await tester.tap(find.text('原入口扫码'));
    await tester.pumpAndSettle();
    expect(find.byType(MemberScannerPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'camera fills page, toolbar toggles light and analyzes selected photo',
    (tester) async {
      final original = MobileScannerPlatform.instance;
      final camera = _Camera();
      MobileScannerPlatform.instance = camera;
      addTearDown(() => MobileScannerPlatform.instance = original);
      await tester.pumpWidget(
        MaterialApp(
          home: MemberScannerPage(pickPhoto: () async => XFile('/test/qr.png')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('扫一扫'), findsNothing);
      expect(find.byTooltip('返回'), findsOneWidget);
      expect(
        tester.getRect(find.byType(MobileScanner)),
        tester.getRect(find.byType(Scaffold)),
      );
      await tester.tap(find.byTooltip('闪光灯'));
      await tester.pump();
      expect(camera.torches, 1);
      await tester.tap(find.byTooltip('相册'));
      await tester.pumpAndSettle();
      expect(camera.analyzed, '/test/qr.png');
      expect(find.text('照片中未识别到二维码，请选择清晰的二维码照片'), findsOneWidget);
      await tester.tap(find.text('重新扫描'));
      await tester.pumpAndSettle();
      expect(camera.starts, 2);
      final controls = tester.widget<Container>(
        find.byKey(const ValueKey('scanner-controls')),
      );
      expect(controls.decoration, isNull);
      await tester.tap(find.byTooltip('切换摄像头'));
      await tester.pumpAndSettle();
      expect(camera.starts, 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
