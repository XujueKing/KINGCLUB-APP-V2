import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/partners/presentation/partner_customer_directory_page.dart';
import 'package:kingclub/src/features/partners/presentation/partner_customer_detail_page.dart';

import 'partner_customer_directory_test.dart' as fixtures;

void main() {
  testWidgets('capture reconstructed customer directory and detail', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await (FontLoader('CustomerQA')..addFont(
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
    final theme = KingTheme.dark.copyWith(
      textTheme: KingTheme.dark.textTheme.apply(fontFamily: 'CustomerQA'),
    );
    Future<Map<String, dynamic>> call(Map<String, dynamic> p) async =>
        p['action'] == 'directory'
        ? {
            'items': [
              for (var i = 0; i < 5; i++)
                {
                  ...fixtures.customer(),
                  'ref': 'U${i + 1}',
                  'name': ['测试会员', '测试合作者', '测试用户', '测试顾客', '测试账号'][i],
                  'realName': null,
                },
            ],
            'total': 5,
            'hasMore': false,
          }
        : fixtures.profile();
    for (final (name, page) in [
      ('customer-directory', PartnerCustomerDirectoryPage(call: call)),
      (
        'customer-detail',
        PartnerCustomerDetailPage(call: call, targetAccount: 'U00000000002'),
      ),
    ]) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: page,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final picture =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/partner-qa').create(recursive: true);
        await File('build/partner-qa/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      expect(tester.takeException(), isNull);
    }
  }, skip: Platform.environment['KINGCLUB_QA_FONT'] == null);
}
