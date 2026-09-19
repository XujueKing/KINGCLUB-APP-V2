import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/bottle_material_preview.dart';
import 'package:kingclub/src/features/shell/presentation/app_shell_page.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';

void main() {
  testWidgets('capture legacy and generated bottle comparison', (tester) async {
    tester.view.physicalSize = const Size(360, 802);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);
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
    final key = GlobalKey();
    final repo = BottleMaterialPreviewRepository();
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
            storageRepository: repo,
            onOpenScanner: (_, _) async => null,
            onOpenTogether: () {},
            onOpenParty: () {},
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final item in repo.items) {
        await precacheImage(AssetImage(item.image), key.currentContext!);
        await precacheImage(AssetImage(item.thumbnail), key.currentContext!);
      }
    });
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final picture =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/bottle-material-qa').create(recursive: true);
        await File('build/bottle-material-qa/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }

    for (final ref in ['legacy-chivas', 'bottle_01']) {
      await tester.tap(find.byKey(ValueKey('storage-select-$ref')));
      await tester.pumpAndSettle();
      await capture('$ref-front');
      await tester.tap(find.text('测试余量'));
      await tester.pumpAndSettle();
      tester.widget<Slider>(find.byType(Slider)).onChanged!(100);
      await tester.pump();
      Navigator.of(tester.element(find.byType(Slider))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await capture('$ref-back');
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  }, skip: Platform.environment['KINGCLUB_QA_FONT'] == null);
}
