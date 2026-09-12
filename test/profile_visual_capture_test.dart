import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';
import 'package:kingclub/src/features/shell/presentation/app_shell_page.dart';

void main() {
  testWidgets('capture native profile expanded and pinned', (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader('ProfileQA')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File(Platform.environment['KINGCLUB_QA_FONT']!)
                  .readAsBytes(),
            ),
          ),
        );
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
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
            textTheme: KingTheme.dark.textTheme.apply(fontFamily: 'ProfileQA'),
          ),
          home: AppShellPage(
            initialIndex: 4,
            onOpenScanner: (_, _) async => null,
            onOpenTogether: () {},
            onOpenParty: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/profile-qa').create(recursive: true);
        await File('build/profile-qa/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.runAsync(() async {
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      await Future.wait(
        images.map((image) => precacheImage(image.image, key.currentContext!)),
      );
    });
    await tester.pumpAndSettle();
    await capture('expanded');
    final scroll = tester
        .widget<CustomScrollView>(
          find.descendant(
            of: find.byType(MyProfilePage),
            matching: find.byType(CustomScrollView),
          ),
        )
        .controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent - 80);
    await tester.pumpAndSettle();
    await capture('approaching-pinned');
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await capture('pinned');
    expect(tester.takeException(), isNull);
  }, skip: Platform.environment['KINGCLUB_QA_FONT'] == null);
}
