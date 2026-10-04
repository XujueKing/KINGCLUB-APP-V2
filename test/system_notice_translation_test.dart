import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_localizations.dart';
import 'package:kingclub/src/features/messaging/presentation/system_notice_copy.dart';

void main() {
  for (final locale in kingSupportedLocales) {
    testWidgets('system notice keeps transaction meanings in $locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: kingSupportedLocales,
          localizationsDelegates: kingLocalizationDelegates,
          home: Builder(
            builder: (context) => Column(
              children: [
                for (final key in [
                  'receipt',
                  'wine_collected',
                  'recharge_paid',
                  'read_all',
                ])
                  Text(systemNoticeText(context, key)),
              ],
            ),
          ),
        ),
      );
      if (locale.languageCode == 'en') {
        expect(find.text('Reference number:'), findsOneWidget);
        expect(find.text('Drinks collected'), findsOneWidget);
        expect(find.text('Receipt:'), findsNothing);
      } else if (locale.languageCode == 'th') {
        expect(find.text('หมายเลขอ้างอิง:'), findsOneWidget);
        expect(find.text('ทำเครื่องหมายทั้งหมดว่าอ่านแล้ว'), findsOneWidget);
        expect(find.text('ใบเสร็จ:'), findsNothing);
      } else {
        expect(
          find.text('业务编号：').evaluate().length +
              find.text('業務編號：').evaluate().length,
          1,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
