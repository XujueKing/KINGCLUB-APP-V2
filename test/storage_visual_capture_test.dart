import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/data/storage_repository.dart';
import 'package:kingclub/src/features/shell/presentation/app_shell_page.dart';

import 'storage_replica_test.dart' show fixture;

void main() {
  testWidgets('capture storage visual states', (tester) async {
    await tester.runAsync(() async {
      final font = File(Platform.environment['KINGCLUB_QA_FONT']!);
      final loader = FontLoader('StorageQA')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
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
          home: AppShellPage(
            initialIndex: 3,
            storageRepository: PreviewStorageRepository(
              Platform.environment['KINGCLUB_QA_FULL'] == '1'
                  ? [
                      StorageItem(
                        ref: 'wine-1',
                        name: fixture.first.name,
                        assetKey: 'vodka',
                        quantity: 2,
                      ),
                      ...fixture.skip(1),
                    ]
                  : fixture,
            ),
            onOpenScanner: (_, _) async => null,
            onOpenTogether: () {},
            onOpenParty: () {},
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final item in fixture) {
        await precacheImage(AssetImage(item.image), key.currentContext!);
        await precacheImage(AssetImage(item.thumbnail), key.currentContext!);
      }
    });
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/storage-qa').create(recursive: true);
        await File('build/storage-qa/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('wine-front');
    await tester.tap(find.byKey(const ValueKey('storage-flip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    await capture('wine-back');
    await tester.tap(find.byKey(const ValueKey('storage-tab-物-idle')));
    await tester.pumpAndSettle();
    await capture('coupon-front');
    await tester.tap(find.byKey(const ValueKey('storage-flip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    await capture('coupon-back');
  }, skip: Platform.environment['KINGCLUB_QA_FONT'] == null);
}
