import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kingclub/src/features/partners/presentation/partner_candidate_page.dart';

void main() {
  testWidgets(
    'selection searches and paginates without exposing a manual account field',
    (t) async {
      final calls = <Map<String, dynamic>>[];
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData.dark(),
          home: PartnerCandidatePage(
            taskRef: 'task',
            merchant: false,
            call: (p) async {
              calls.add(Map.of(p));
              return {
                'items': p['query'] == 'Alice'
                    ? [
                        {'ref': 'selected', 'name': 'Alice'},
                      ]
                    : List.generate(
                        p['page'] == 0 ? 30 : 1,
                        (i) => {'ref': '${p['page']}-$i', 'name': '顾客 $i'},
                      ),
              };
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(calls.single['action'], 'task_candidates');
      await t.scrollUntilVisible(
        find.text('加载更多'),
        600,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(find.text('加载更多'));
      await t.pumpAndSettle();
      expect(calls.last['page'], 1);
      await t.enterText(find.byType(TextField), 'Alice');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(calls.last['page'], 0);
      expect(calls.last['query'], 'Alice');
      expect(find.widgetWithText(ListTile, 'Alice'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('failed candidate read can retry and show empty result', (
    t,
  ) async {
    var n = 0;
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: PartnerCandidatePage(
          taskRef: 'task',
          merchant: true,
          call: (p) async {
            if (n++ == 0) throw Exception('offline');
            return {'items': []};
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('重试'));
    await t.pumpAndSettle();
    expect(find.text('暂无可选择的对象'), findsOneWidget);
    expect(n, 2);
  });
}
