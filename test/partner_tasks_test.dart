import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kingclub/src/features/partners/data/partner_repository.dart';
import 'package:kingclub/src/features/partners/presentation/partner_tasks_page.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

Widget app(PartnerCall call, {String kind = 'tasks', String? ref}) =>
    MaterialApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData.dark(),
      home: PartnerTasksPage(call: call, kind: kind, taskRef: ref),
    );
Map<String, dynamic> detail() => {
  'isAdmin': false,
  'task': {
    'ref': 'task',
    'kind': 'member',
    'title': '新会员任务',
    'description': '测试规则，仅用于自动化测试',
    'minimumCents': '800',
    'maximumCents': '2000',
    'endsAt': '2027-01-01',
    'available': true,
    'status': 'published',
  },
  'claim': null,
};
void main() {
  testWidgets('ledger formats exact cents and never offers withdrawal', (
    tester,
  ) async {
    await tester.pumpWidget(
      app((_) async => {'pendingCents': '123456', 'items': []}, kind: 'ledger'),
    );
    await tester.pumpAndSettle();
    expect(find.text('¥1,234.56'), findsOneWidget);
    expect(find.text('提现'), findsNothing);
  });
  testWidgets('claim retries the same id after unknown outcome', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      app((p) async {
        if (p['action'] == 'task_claim') {
          calls.add(Map.of(p));
          throw Exception('timeout');
        }
        return detail();
      }, ref: 'task'),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton).last);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(calls.length, 2);
    expect(calls[0], calls[1]);
  });
  testWidgets('business rejection unlocks evidence for correction', (
    tester,
  ) async {
    await tester.pumpWidget(
      app((p) async {
        if (p['action'] == 'task_candidates')
          return {
            'items': [
              {'ref': 'picked', 'name': '已关联顾客'},
            ],
          };
        if (p['action'] == 'task_submit') {
          throw const AuthFailure('PARTNER_EVIDENCE_INVALID', 'invalid');
        }
        return {
          ...detail(),
          'claim': {'ref': 'claim', 'status': 'claimed', 'reason': ''},
        };
      }, ref: 'task'),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('选择已关联顾客'));
    await tester.tap(find.text('选择已关联顾客'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已关联顾客'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '说明');
    await tester.ensureVisible(find.text('提交验收'));
    await tester.tap(find.text('提交验收'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).readOnly,
      false,
    );
  });
  testWidgets('empty task list does not display invented rewards', (
    tester,
  ) async {
    await tester.pumpWidget(app((_) async => {'isAdmin': false, 'items': []}));
    await tester.pumpAndSettle();
    expect(find.text('暂无记录'), findsOneWidget);
    expect(find.text('创建任务'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
