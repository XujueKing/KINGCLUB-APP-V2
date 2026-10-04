import 'package:kingclub/src/core/design_system/king_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/secure_together_play_repository.dart';
import 'package:kingclub/src/features/club/presentation/together_entry_page.dart';
import 'package:kingclub/src/features/home/data/home_city_catalog.dart';

void main() {
  testWidgets(
    'entry without a known city offers selection without layout errors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: kingSupportedLocales.first,
          supportedLocales: kingSupportedLocales,
          localizationsDelegates: kingLocalizationDelegates,
          home: TogetherEntryPage(onBack: () {}, restoreCity: () async => null),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('选择城市，查看同城组局'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('entry uses selected city and never substitutes sample tickets', (
    tester,
  ) async {
    final calls = <String>[];
    final repo = SecureTogetherPlayRepository(
      readSession: () async => {
        'account': {'userAccount': 'test-member'},
        'sessionId': 'test-session',
        'apiKeyId': 'test-key',
        'apiKey': 'test-only',
      },
      request: (id, params, _) async {
        calls.add(id);
        expect(params['cityCode'], '430200');
        return {
          'result': {
            'cityCode': params['cityCode'],
            'startsFrom': params['startsFrom'],
            'startsBefore': params['startsBefore'],
            'items': [],
            'next': null,
          },
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: kingSupportedLocales.first,
        supportedLocales: kingSupportedLocales,
        localizationsDelegates: kingLocalizationDelegates,
        home: TogetherEntryPage(
          onBack: () {},
          repository: repo,
          initialCity: const HomeCity(
            code: '430200',
            name: '株洲市',
            shortName: '株洲',
            pinyin: 'zhuzhou',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, ['K261004001985']);
    expect(find.text('这一天还没有同城组局'), findsOneWidget);
    expect(find.text('888'), findsNothing);
    expect(find.textContaining('请按时到场'), findsNothing);
    expect(find.text('发起组局'), findsNothing);
    expect(find.text('加入派对'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('together-city-selector')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
