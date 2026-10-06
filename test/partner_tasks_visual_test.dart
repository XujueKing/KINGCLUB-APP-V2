import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/partners/presentation/partner_tasks_page.dart';

void main() {
  testWidgets('capture task list in current app theme', (tester) async {
    await tester.runAsync(() async {
      await (FontLoader('PartnerQA')..addFont(
            Future.value(
              ByteData.sublistView(
                await File(Platform.environment['KINGCLUB_QA_FONT']!)
                    .readAsBytes(),
              ),
            ),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
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
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: KingTheme.dark.copyWith(
            textTheme: KingTheme.dark.textTheme.apply(fontFamily: 'PartnerQA'),
          ),
          home: PartnerTasksPage(
            call: (_) async => {
              'isAdmin': true,
              'canCreate': true,
              'items': [
                {
                  'ref': 'qa-task',
                  'title': '测试任务 · 邀请新会员',
                  'kind': 'member',
                  'status': 'published',
                  'minimumCents': '800',
                  'maximumCents': '2000',
                  'endsAt': '2026-11-01',
                },
              ],
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final pic =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await pic.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/partner-qa').create(recursive: true);
      await File('build/partner-qa/tasks.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      pic.dispose();
    });
    expect(tester.takeException(), isNull);
  }, skip: Platform.environment['KINGCLUB_QA_FONT'] == null);
}
