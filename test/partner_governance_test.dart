import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/partners/presentation/partner_risk_page.dart';
import 'package:kingclub/src/features/partners/presentation/partner_notice_destination.dart';

import 'partner_platform_test.dart' show app, snapshot;
import 'support/partner_governance_fixtures.dart';

Widget riskApp(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);
const caseRef = 'b5b04542-8151-4e28-9983-616e243adf61';
Map<String, dynamic> detail({
  bool review = false,
  String kind = 'complaint',
  String status = 'open',
  int version = 1,
}) => {
  'canReview': review,
  'canAppeal': kind == 'violation',
  'item': {
    'ref': caseRef,
    'title': 'Synthetic case',
    'kind': kind,
    'status': status,
    'version': version,
    'description': 'Synthetic documented case evidence',
    'memberId': 'KMTEST',
    'date': '2030-01-01',
    'relatedReference': '',
    'ruleReference': '',
  },
  'events': <Map<String, dynamic>>[],
};
void main() {
  testWidgets(
    'application cannot submit or precheck consent just by opening terms',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        app((p) async {
          requests.add(Map.of(p));
          return p['action'] == 'terms' ? termsSnapshot() : snapshot();
        }),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('申请成为合作者').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('提交申请'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('提交申请'));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r['action'] == 'apply'), isEmpty);
      expect(find.text('请先打开条款阅读，并勾选同意后提交'), findsOneWidget);
      final checkbox = find.byKey(const ValueKey('partner-terms-checkbox'));
      expect(tester.widget<Checkbox>(checkbox).value, false);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(requests.where((r) => r['action'] == 'terms').length, 1);
      expect(find.text('KINGCLUB合作者条款和规则'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('partner-terms-read')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('partner-terms-read')));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(checkbox).value, false);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(checkbox).value, true);
    },
  );
  testWidgets(
    'ordinary partner risk page offers complaints but no management actions',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        riskApp(
          PartnerRiskPage(
            call: (p) async {
              requests.add(Map.of(p));
              return {
                'canReview': false,
                'items': [detail()['item']],
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.single, {'action': 'risk', 'review': 0, 'page': 0});
      expect(find.text('提交投诉'), findsOneWidget);
      expect(find.text('违规处理通知'), findsNothing);
      expect(find.text('完成处理'), findsNothing);
      expect(find.text('解除限制'), findsNothing);
    },
  );
  testWidgets(
    'complaint timeout retry retains exact fields and id without an account selector',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        riskApp(
          PartnerRiskForm(
            call: (p) async {
              requests.add(Map.of(p));
              throw StateError('timeout');
            },
          ),
        ),
      );
      expect(find.byKey(const ValueKey('partner-risk-memberId')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('partner-risk-riskTitle')),
        'Synthetic complaint',
      );
      await tester.enterText(
        find.byKey(const ValueKey('partner-risk-riskDescription')),
        'Synthetic documented complaint evidence',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('partner-risk-submit')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('partner-risk-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('partner-risk-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('partner-risk-submit')));
      await tester.pumpAndSettle();
      expect(requests.length, 2);
      expect(requests[0], requests[1]);
      expect(requests.first['kind'], 'complaint');
      expect(requests.first.containsKey('ownerAccount'), false);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('partner-risk-riskDescription')),
            )
            .readOnly,
        true,
      );
    },
  );
  testWidgets(
    'admin decisions carry current case version and require a spaced confirmation',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> call(Map<String, dynamic> p) async {
        requests.add(Map.of(p));
        return {
          ...detail(review: true),
          if (p['requestId'] != null) 'receiptRef': p['requestId'],
        };
      }

      await tester.pumpWidget(
        riskApp(
          PartnerRiskDetail(call: call, reference: caseRef, review: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('完成处理'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('完成处理'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('partner-risk-riskReason')),
        'Verified synthetic facts and documented resolution',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('partner-risk-submit')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('partner-risk-submit')));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r['action'] == 'risk_decide'), isEmpty);
      final confirm = find.text('确认');
      final cancel = find.text('取消');
      expect(
        tester.getRect(confirm).left - tester.getRect(cancel).right,
        greaterThan(16),
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final p = requests.singleWhere((r) => r['action'] == 'risk_decide');
      expect(p['review'], 1);
      expect(p['caseRef'], caseRef);
      expect(p['expectedVersion'], 1);
      expect(p['decision'], 'resolve');
    },
  );
  test('risk notices use personal and authorized management destinations', () {
    Future<Map<String, dynamic>> call(Map<String, dynamic> _) async => {};
    expect(
      (partnerNoticeDestination('risk', call: call) as PartnerRiskPage).review,
      false,
    );
    expect(
      (partnerNoticeDestination(
        'risk:review',
        call: call,
      ) as PartnerRiskPage).review,
      true,
    );
  });
}
