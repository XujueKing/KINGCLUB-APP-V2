import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:kingclub/src/features/scanner/presentation/member_scanner_page.dart';

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

void main() {
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
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/scanner'),
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
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(),
              child: Text('返回 ${state.uri.queryParameters['tableId']}'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('打开扫码'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('相册'));
    await tester.pumpAndSettle();
    expect(find.text('返回 V2'), findsOneWidget);
    expect(find.byType(MemberScannerPage), findsNothing);
    await tester.tap(find.text('返回 V2'));
    await tester.pumpAndSettle();
    expect(find.text('打开扫码'), findsOneWidget);
    expect(find.byType(MemberScannerPage), findsNothing);
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
