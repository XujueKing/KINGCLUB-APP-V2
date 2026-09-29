import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:kingclub/src/features/scanner/presentation/member_scanner_page.dart';

class _Camera extends MobileScannerPlatform {
  int starts = 0, torches = 0;
  String? analyzed;
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
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
    return null;
  }
}

void main() {
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
      await tester.tap(find.text('闪光灯'));
      await tester.pump();
      expect(camera.torches, 1);
      await tester.tap(find.text('相册'));
      await tester.pumpAndSettle();
      expect(camera.analyzed, '/test/qr.png');
      expect(find.text('照片中未识别到二维码，请选择清晰的二维码照片'), findsOneWidget);
      await tester.tap(find.text('重新扫描'));
      await tester.pumpAndSettle();
      expect(camera.starts, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
