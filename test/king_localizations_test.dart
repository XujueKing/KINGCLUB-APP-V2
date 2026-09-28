import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_localizations.dart';
import 'package:kingclub/src/features/commerce/presentation/ordering_entry_status.dart';

void main() {
  for (final entry in <Locale, String>{
    const Locale('zh', 'CN'): '门店桌台设置',
    const Locale('zh', 'TW'): '門店桌台設定',
    const Locale('en', 'US'): 'Store tables',
    const Locale('th', 'TH'): 'ตั้งค่าโต๊ะของร้าน',
    const Locale('fr', 'FR'): '门店桌台设置',
  }.entries) {
    testWidgets(
      'resolves device ${entry.key} and loads date-picker localization',
      (tester) async {
        tester.platformDispatcher.localesTestValue = [entry.key];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await tester.pumpWidget(
          MaterialApp(
            supportedLocales: kingSupportedLocales,
            localizationsDelegates: kingLocalizationDelegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    Text(
                      OrderingEntryStatus.text(
                        Localizations.localeOf(context),
                        [
                          '门店桌台设置',
                          'Store tables',
                          '門店桌台設定',
                          'ตั้งค่าโต๊ะของร้าน',
                        ],
                      ),
                    ),
                    Text(MaterialLocalizations.of(context).cancelButtonLabel),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        if (entry.key.languageCode == 'zh' && entry.key.countryCode == 'CN') {
          expect(find.text('取消'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
