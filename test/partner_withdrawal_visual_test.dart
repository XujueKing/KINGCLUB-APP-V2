import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/rendering.dart';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:kingclub/src/core/design_system/king_theme.dart';

import 'package:kingclub/src/features/partners/presentation/partner_withdrawal_page.dart';

void main() {
  testWidgets('capture manual withdrawal in current app theme', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

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
            appBarTheme: const AppBarTheme(
              titleTextStyle: TextStyle(fontFamily: 'PartnerQA', fontSize: 17),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                textStyle: const TextStyle(fontFamily: 'PartnerQA'),
              ),
            ),

            textTheme: KingTheme.dark.textTheme.apply(fontFamily: 'PartnerQA'),
          ),

          home: PartnerWithdrawalPage(
            call: (_) async => {
              'userAccount': 'U00000000001',
              'availableCents': '123456',
              'canWithdraw': true,
              'cards': [
                {
                  'ref': 'qa-card',
                  'bankName': '测试银行',
                  'accountMasked': '•••• 0001',
                  'payeeName': '测试收款人',
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

      await File('build/partner-qa/withdrawal.png')
          .writeAsBytes(bytes!.buffer.asUint8List());

      pic.dispose();
    });

    expect(tester.takeException(), isNull);
  }, skip: Platform.environment['KINGCLUB_QA_FONT'] == null);
}
