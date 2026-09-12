import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/data/storage_repository.dart';
import 'package:kingclub/src/features/club/presentation/real_storage_pickup_page.dart';

const coupon = StorageItem(
  ref: 'visual-coupon',
  name: '首次AA免单券',
  assetKey: 'aa-ticket',
  category: 'item',
  description: '[首次AA免单券]是会员在APP预定AA套餐时，抵用会员自己的消费，最大可抵用388元。',
  maximumValue: 388,
  storedAt: '2026-09-08T22:41:53',
  expiresAt: '2026-11-07T22:41:53',
);

class VisualRepo extends PreviewStorageRepository {
  VisualRepo() : super([coupon]);
  @override
  Future<Map<String, dynamic>> issue(String ref) async => {
    'token': 'visual-only-not-redeemable-credential',
    'expiresInSeconds': 30,
  };
}

void main() {
  testWidgets('capture voucher pickup layout', (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader('StorageQA')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File(Platform.environment['KINGCLUB_QA_FONT']!)
                  .readAsBytes(),
            ),
          ),
        );
      await loader.load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: KingTheme.dark.copyWith(
            textTheme: KingTheme.dark.textTheme.apply(fontFamily: 'StorageQA'),
          ),
          home: RealStoragePickupPage(item: coupon, repository: VisualRepo()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/storage-qa').create(recursive: true);
      await File('build/storage-qa/coupon-pickup.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  }, skip: Platform.environment['KINGCLUB_QA_FONT'] == null);
}
