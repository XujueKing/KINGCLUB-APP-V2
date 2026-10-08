import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_localizations.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/presentation/party_allocation_page.dart';

Map<String, dynamic> detail({bool assigned = false}) => {
  'storeRef': 'store',
  'party': {'ref': 'party', 'theme': '周末AA邀请', 'canAssign': true},
  'tables': [
    {
      'ref': 'v1',
      'name': 'V1',
      'capacity': 4,
      'assignedCount': assigned ? 1 : 0,
      'active': true,
    },
  ],
  'members': [
    {
      'bookingRef': '00000000-0000-4000-8000-000000000002',
      'nickname': '顾客甲',
      'admitted': false,
      'tableRef': assigned ? 'v1' : null,
      'tableName': assigned ? 'V1' : null,
    },
    {
      'bookingRef': '00000000-0000-4000-8000-000000000003',
      'nickname': '顾客乙',
      'admitted': true,
      'tableRef': 'v1',
      'tableName': 'V1',
    },
  ],
};
Future<void> mount(
  WidgetTester t,
  Widget page, {
  Size size = const Size(390, 844),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      locale: kingSupportedLocales.first,
      supportedLocales: kingSupportedLocales,
      localizationsDelegates: kingLocalizationDelegates,
      theme: KingTheme.dark,
      home: page,
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'one detail request, only unadmitted guests selectable, and mutation updates full page without refetch',
    (t) async {
      final calls = <Map<String, dynamic>>[];
      await mount(
        t,
        PartyAllocationDetailPage(
          storeRef: 'store',
          partyRef: 'party',
          call: (p) async {
            calls.add(p);
            return p['action'] == 'assign'
                ? {
                    ...detail(assigned: true),
                    'operation': {'requestId': p['requestId']},
                  }
                : detail();
          },
        ),
      );
      expect(calls.length, 1);
      final admitted = t.widget<CheckboxListTile>(
        find.byKey(
          const ValueKey('guest-00000000-0000-4000-8000-000000000003'),
        ),
      );
      expect(admitted.onChanged, isNull);
      await t.tap(
        find.byKey(
          const ValueKey('guest-00000000-0000-4000-8000-000000000002'),
        ),
      );
      await t.pump();
      await t.tap(find.byType(RadioListTile<String>));
      await t.pump();
      final button = find.widgetWithText(FilledButton, '确认安排');
      expect(t.getSize(button).height, 52);
      await t.tap(button);
      await t.pumpAndSettle();
      expect(calls.map((v) => v['action']), ['detail', 'assign']);
      expect(calls.last['bookingRefs'], [
        '00000000-0000-4000-8000-000000000002',
      ]);
      expect(find.text('1 / 4 人'), findsOneWidget);
      expect(find.text('位置安排成功'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'uncertain action retries original request and selection without a false success',
    (t) async {
      final calls = <Map<String, dynamic>>[];
      await mount(
        t,
        PartyAllocationDetailPage(
          storeRef: 'store',
          partyRef: 'party',
          call: (p) async {
            calls.add(Map.of(p));
            if (p['action'] == 'assign') throw StateError('网络中断');
            return detail();
          },
        ),
      );
      await t.tap(find.byType(RadioListTile<String>));
      await t.pump();
      await t.tap(
        find.byKey(
          const ValueKey('guest-00000000-0000-4000-8000-000000000002'),
        ),
      );
      await t.pump();
      for (var i = 0; i < 2; i++) {
        await t.tap(find.widgetWithText(FilledButton, '确认安排'));
        await t.pumpAndSettle();
      }
      expect(calls.length, 3);
      expect(calls[1], calls[2]);
      expect(find.text('位置安排成功'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'small screen and larger text remain scrollable with full size action',
    (t) async {
      await mount(
        t,
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: PartyAllocationDetailPage(
            storeRef: 'store',
            partyRef: 'party',
            call: (_) async => detail(),
          ),
        ),
        size: const Size(320, 568),
      );
      expect(find.byType(ListView), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(t.getSize(find.widgetWithText(FilledButton, '确认安排')).height, 52);
    },
  );
}
